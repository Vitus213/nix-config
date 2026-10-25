{
  config,
  lib,
  pkgs,
  ...
}:
let
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
    # 新 tab 不弹命名框：手动起的名字会让 auto-title 插件不再接管该 tab。
    prompt_new_tab_name = false
  '';
in
{
  #############################################################
  #
  #  Basic settings for development environment
  #
  #  Please avoid to install language specific packages here(globally),
  #  instead, install them:
  #     1. per IDE, such as `programs.neovim.extraPackages`
  #     2. per-project, using https://github.com/the-nix-way/dev-templates
  #
  #############################################################

  home.packages = with pkgs; [
    just
    colmena # nixos's remote deployment tool
    # herdr 二进制改用官方安装（curl -fsSL https://herdr.dev/install.sh | sh，
    # 装至 ~/.local/bin），更新走 `herdr update` 自管理，不在 nix 里固化。
    # 配置由下方 home.activation.herdrConfig 生成。

    tokei # count lines of code, alternative to cloc

    sqlite

    # misc
    gitleaks
  ];

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
    direnv = {
      enable = true;
      nix-direnv.enable = true;

      enableZshIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
    };
  };
}
