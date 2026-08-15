{
  config,
  lib,
  pkgs,
  ...
}:
###########################################################
#
# 当前保留的终端模拟器：
#   - Linux:  foot（Mod+Return 主终端） + alacritty（Mod+Shift+Return 备用）
#   - macOS:  ghostty（Homebrew cask 安装） + alacritty
#
# ghostty 和 kitty 已不再用于 Linux 桌面。标签页、复制、搜索、滚动历史和
# 工作区交给 Zellij，终端只提供基础能力。
#
###########################################################
let
  # ghostty 配置的渲染逻辑；darwin 上由 Homebrew 安装应用，
  # Home Manager 只负责写配置文件，因此不走 programs.ghostty.enable。
  formatValue =
    value:
    if builtins.isBool value then
      lib.boolToString value
    else if builtins.isFloat value || builtins.isInt value then
      toString value
    else if builtins.isString value then
      value
    else
      throw "Unsupported Ghostty setting value: ${builtins.typeOf value}";

  renderSettings =
    settings:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: value:
        lib.concatStringsSep "\n" (
          map (item: "${name} = ${formatValue item}") (if builtins.isList value then value else [ value ])
        )
      ) settings
    )
    + "\n";
in
{
  programs.foot = {
    # foot 只支持 Linux
    enable = pkgs.stdenv.isLinux;

    # server 模式下由一个常驻进程托管所有窗口，footclient 只负责开窗，
    # 降低内存占用并加快新窗口启动。
    server.enable = true;

    # https://man.archlinux.org/man/foot.ini.5
    settings = {
      main = {
        term = "foot"; # or "xterm-256color" for maximum compatibility
        font = "Maple Mono NF CN:size=13";
        dpi-aware = "no"; # scale via window manager instead
        resize-keep-grid = "no"; # do not resize the window on font resizing

        # Spawn a nushell in login mode via `bash`
        shell = "${pkgs.bash}/bin/bash --login -c 'nu --login --interactive'";
      };

      mouse = {
        hide-when-typing = "yes";
      };
    };
  };

  # ghostty 不再通过 Home Manager 安装到任何平台：
  #   - Linux 已改用 foot + alacritty
  #   - macOS 由 Homebrew cask 安装，这里仅声明 settings 供下方配置文件引用
  programs.ghostty = {
    enable = false;
    settings = {
      font-family = "Maple Mono NF CN";
      # mkDefault: darwin 的 terminal.nix 会用 mkForce 覆盖为 15
      font-size = lib.mkDefault 13;

      background-opacity = 0.93;
      # only supported on macOS;
      background-blur-radius = 10;
      scrollback-limit = 20000;

      # https://ghostty.org/docs/config/reference#command
      #  Spawn a nushell in login mode via `bash`
      command = "${pkgs.bash}/bin/bash --login -c 'nu --login --interactive'";
    };
  };

  # macOS 上 Ghostty 通过 Homebrew cask 安装，配置文件直接写入 XDG 目录。
  xdg.configFile."ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    text = renderSettings config.programs.ghostty.settings;
  };
}
