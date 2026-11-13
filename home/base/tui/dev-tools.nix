{
  config,
  lib,
  pkgs,
  osConfig ? null,
  ...
}:
let
  developmentHost =
    osConfig != null
    && builtins.elem (osConfig.networking.hostName or "") [
      "apollo"
      "athena"
    ];

  # herdr 配置不再以只读 symlink 部署：herdr-radar 插件与 herdr 自身都会改写
  # config.toml。这里只声明基础内容，由下方 activation 合并插件的托管块。
  # 约束：[ui] 必须是最后一个表——radar 的 tab-bar 块是 [ui] 下的裸键。
  herdrBaseConfig = pkgs.writeText "herdr-config.toml" ''
    onboarding = false

    [terminal]
    # 用稳定 profile 路径而非 nushell 的 store 绝对路径：长驻的 herdr server
    # 只在启动/重载时读配置，store 路径会在 nushell 升级后指向旧二进制。
    default_shell = "${config.home.profileDirectory}/bin/nu"
    shell_mode = "login"

    # radar 在读不到桌面明暗时按主题名选配色；不写则回退浅色配色。
    [theme]
    name = "catppuccin"

    [[keys.command]]
    key = "prefix+a"
    type = "plugin_action"
    command = "hhdebb.herdr-radar.view-flip"
    description = "Agents: active <-> recent"

    [[keys.command]]
    key = "prefix+comma"
    type = "plugin_action"
    command = "hhdebb.herdr-radar.settings"
    description = "herdr-radar settings"

    # 后台 agent 完成/需要输入时的桌面通知：Linux 走 notify-send（noctalia 显示）。
    # terminal 模式只识别 Ghostty/iTerm2/Kitty/WezTerm，foot 下不弹。
    [ui.toast]
    delivery = "system"
    delay_seconds = 1

    [ui]
    # 新 tab 不弹命名框：未命名的 tab 显示位置编号。
    prompt_new_tab_name = false
  '';
in
{
  # 语言工具集中管理，版本随 flake.lock；项目依赖使用现有 direnv/devShell。

  home.packages =
    with pkgs;
    [
      just
      colmena # nixos's remote deployment tool
      google-cloud-sdk
      # herdr 使用官方用户级安装，配置由下方 activation 管理。
      tokei
      sqlite
      gitleaks

      # Python、Rust 从编辑器包列表迁入，保持已有主机的工具链。
      uv
      (python313.withPackages (
        ps: with ps; [
          pyright
          ruff
          pipx
          black
          jupyter
          ipython
          pandas
          requests
          pyquery
          pyyaml
          boto3
          protobuf
          numpy
        ]
      ))

      # 使用 nixpkgs 工具链；rust-analyzer wrapper 已提供匹配的标准库源码。
      rustc
      rust-analyzer
      cargo
      rustfmt
      clippy
    ]
    ++ lib.optionals developmentHost [
      # Go：沿用 ryan4yin 的工具组合。
      gopls
      gomodifytags
      iferr
      impl
      gotools
      delve

      # Gradle 8 的运行 JVM 最高支持 Java 24，默认使用 JDK 21 LTS。
      maven
      gradle_8
    ];

  # Nushell 不保证继承 Bash 的 PATH，补齐 go/cargo install 的用户命令目录。
  programs.nushell.extraEnv = lib.mkIf developmentHost ''
    $env.JAVA_HOME = "${config.programs.java.package.home}"
    $env.PATH = ($env.PATH | append ["${config.home.homeDirectory}/go/bin" "${config.home.homeDirectory}/.cargo/bin"] | uniq)
  '';

  # 写入可写的 config.toml：基础内容 + 保留现有文件中 herdr-radar 的托管块
  # （按 tab-bar、theme、sidebar 顺序追加，与插件自身写入的位置等价）。
  home.activation.herdrConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    herdr_cfg="${config.xdg.configHome}/herdr/config.toml"
    herdr_blocks=""
    if [ -f "$herdr_cfg" ] && [ ! -L "$herdr_cfg" ]; then
      herdr_blocks="$(${pkgs.gawk}/bin/awk '
        /^# >>> herdr-radar (tab-bar|theme|sidebar) block$/ { name = $4; on = 1 }
        on { buf[name] = buf[name] $0 "\n" }
        /^# <<< herdr-radar (tab-bar|theme|sidebar) block$/ { on = 0 }
        END { printf "%s", buf["tab-bar"]; printf "%s", buf["theme"]; printf "%s", buf["sidebar"] }
      ' "$herdr_cfg")"
    fi
    herdr_tmp="$(mktemp)"
    cat ${herdrBaseConfig} > "$herdr_tmp"
    if [ -n "$herdr_blocks" ]; then printf '\n%s\n' "$herdr_blocks" >> "$herdr_tmp"; fi
    run mkdir -p "$(dirname "$herdr_cfg")"
    if [ -L "$herdr_cfg" ]; then run rm -f "$herdr_cfg"; fi
    run install -m 644 "$herdr_tmp" "$herdr_cfg"
    rm -f "$herdr_tmp"
  '';

  # herdr server 独立成 systemd 用户服务，不再挂在启动它的终端窗口的 cgroup 下。
  # 停止该服务会结束所有 pane 进程，因此 HM 切换时不自动重启。
  systemd.user.services.herdr = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    Unit = {
      Description = "Herdr session server";
      Documentation = [ "https://herdr.dev/docs/cli-reference/" ];
      # 需要 graphical-session 导入的 WAYLAND_DISPLAY 等变量，pane 继承服务环境。
      After = [ "graphical-session.target" ];
      X-RestartIfChanged = false;
    };
    Service = {
      # 已有 server（如终端里手动启动的）在跑时跳过，避免抢 socket。
      ExecCondition = "${pkgs.bash}/bin/sh -c '! ${config.home.homeDirectory}/.local/bin/herdr status server | ${pkgs.gnugrep}/bin/grep -q \"^status: running\"'";
      ExecStart = "${config.home.homeDirectory}/.local/bin/herdr server";
      # `herdr server stop` 也会被拉起并恢复会话；真正停止用 systemctl --user stop herdr。
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  programs = {
    go = {
      enable = developmentHost;
      package = pkgs.go;
      env.GOPATH = "${config.home.homeDirectory}/go";
    };

    java = {
      enable = developmentHost;
      package = pkgs.jdk21;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;

      enableZshIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
    };
  };
}
