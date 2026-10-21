{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}:
let
  # agenix 解密位置：NixOS 复制到 /etc/agenix（/run/agenix 对用户不可遍历），darwin 直接读 /run/agenix
  secretPaths = name: [
    "/etc/agenix/${name}"
    "/run/agenix/${name}"
  ];

  # wakatime-cli 通过 api_key_vault_cmd 调用它取 key，明文不落 ~/.wakatime.cfg
  wakatimeApiKey = pkgs.writeShellScriptBin "wakatime-api-key" ''
    for f in ${lib.concatStringsSep " " (secretPaths "wakatime-api-key")}; do
      if [ -r "$f" ]; then
        tr -d '\n' < "$f"
        exit 0
      fi
    done
    echo "wakatime-api-key: 找不到 agenix 解密的 wakatime-api-key" >&2
    exit 1
  '';

  hostName =
    if osConfig != null && (osConfig.networking.hostName or null) != null then
      osConfig.networking.hostName
    else
      "";

  agentUsageReport = pkgs.writeShellApplication {
    name = "agent-usage-report";
    runtimeInputs = [ pkgs.git ];
    text = ''
      exec ${pkgs.python3}/bin/python3 -I ${./agent_usage.py} \
        --ccusage ${lib.getExe pkgs.ccusage} \
        ${lib.optionalString (hostName != "") "--host ${hostName}"} \
        ${lib.concatMapStringsSep " " (p: "--token-file ${p}") (secretPaths "github_token")} \
        "$@"
    '';
  };
in
{
  home.packages = [
    pkgs.ccusage
    wakatimeApiKey
    agentUsageReport
  ];

  # ~/.wakatime.cfg 由 preservation 保留且插件会写入，保持可变，只确保 vault 命令指向稳定 profile 路径
  # 同时删掉明文 api_key 行（它优先于 vault 命令）
  home.activation.wakatimeApiKeyVault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.wakatime-cli}/bin/wakatime-cli --config "$HOME/.wakatime.cfg" \
      --config-write api_key_vault_cmd="${config.home.profileDirectory}/bin/wakatime-api-key" \
      || echo "wakatimeApiKeyVault: 写入 ~/.wakatime.cfg 失败" >&2
    # ~/.wakatime.cfg 在 preservation 主机上是软链接，必须 --follow-symlinks
    run ${pkgs.gnused}/bin/sed --follow-symlinks -i '/^api_key[[:space:]]*=/d' "$HOME/.wakatime.cfg"
  '';

  systemd.user.services.agent-usage-report = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Publish AI agent usage cards to the GitHub profile";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe agentUsageReport;
    };
  };
  systemd.user.timers.agent-usage-report = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit.Description = "Hourly AI agent usage report";
    Timer = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "5m";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  launchd.agents.agent-usage-report = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    enable = true;
    config = {
      ProgramArguments = [ (lib.getExe agentUsageReport) ];
      StartInterval = 3600;
      RunAtLoad = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/agent-usage-report.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/agent-usage-report.log";
    };
  };
}
