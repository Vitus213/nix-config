{
  config,
  lib,
  pkgs,
  ...
}:
###########################################################
#
# 当前保留的终端模拟器：
#   - Linux:  kitty（所有终端入口统一）
#   - macOS:  ghostty（Homebrew cask 安装） + alacritty
#
# Linux kitty 保持直接进入 Nushell，按需手动运行 Zellij 或 herdr。
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
  #   - Linux 使用 kitty
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
