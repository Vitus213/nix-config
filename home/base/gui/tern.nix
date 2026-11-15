{
  config,
  pkgs,
  lib,
  ...
}:
let
  supported = builtins.elem pkgs.stdenv.hostPlatform.system [
    "x86_64-linux"
    "aarch64-darwin"
  ];
  configDir =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "${config.home.homeDirectory}/Library/Application Support/Tern"
    else
      "${config.xdg.configHome}/tern";
in
{
  home.packages = lib.optionals supported [ pkgs.tern-stencil ];

  # 设置保留可写；只合并 Nix 管理更新所需的字段，保留 GUI 保存的偏好。
  home.activation.ternSettings = lib.mkIf supported (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      tern_config=${lib.escapeShellArg configDir}
      run mkdir -p "$tern_config"
      tern_settings="$tern_config/settings.json"
      tern_tmp="$(mktemp "$tern_config/.settings.XXXXXX")"
      if [ -f "$tern_settings" ]; then
        ${lib.getExe pkgs.jq} '. + {auto_update: false}' "$tern_settings" > "$tern_tmp"
      else
        printf '{"auto_update": false}\n' > "$tern_tmp"
      fi
      run install -m 600 "$tern_tmp" "$tern_settings"
      rm -f "$tern_tmp"
    ''
  );
}
