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
#             + kitty（Mod+Ctrl+Return，SSH 里给 OMP 贴剪贴板图片用）
#   - macOS:  ghostty（Homebrew cask 安装） + alacritty
#
# ghostty 不再用于 Linux 桌面。标签页、复制、搜索、滚动历史和工作区交给
# Zellij，终端只提供基础能力；kitty 是例外，见下方注释。
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
    enable = pkgs.stdenv.hostPlatform.isLinux;

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

      # niri 未启用 prefer-no-csd，foot 会自绘标题栏；平铺下无用，只关 foot 的。
      csd = {
        preferred = "none";
      };
    };
  };

  # foot.server 生成的 foot.service 与显示器就绪存在竞速：foot --server
  # 拿不到输出会立即退出，默认 RestartSec=100ms 连试 5 次即触发 start-limit，
  # 之后整个会话 footclient 无 server 可连（Win+Return 失灵）。
  # 放宽为每 2s 重试且不限次数，显示器就绪后自动补起。
  systemd.user.services.foot = {
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = 2;
  };

  # kitty：唯一实现 OSC 5522 剪贴板读取协议的常用终端。OMP 在 SSH 会话里
  # 粘贴图片只走该协议（foot 只有 OSC 52 文本剪贴板），herdr client 亦内置
  # 同协议处理；用 kitty 作外层终端即可粘贴本机截图给远程 OMP。
  # 读剪贴板时 kitty 默认弹授权确认，保持 ask，不自动放行。
  programs.kitty = {
    # 仅 Linux；macOS 终端仍是 Homebrew 的 ghostty
    enable = pkgs.stdenv.hostPlatform.isLinux;

    # https://sw.kovidgoyal.net/kitty/conf.html
    settings = {
      font_family = "Maple Mono NF CN";
      font_size = "13.0";
      scrollback_lines = 20000;
      # Spawn a nushell in login mode via `bash`
      shell = "${pkgs.bash}/bin/bash --login -c 'nu --login --interactive'";
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
  xdg.configFile."ghostty/config" = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    text = renderSettings config.programs.ghostty.settings;
  };
}
