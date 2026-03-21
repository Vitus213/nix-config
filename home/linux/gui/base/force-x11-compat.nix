{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.desktop.forceX11Compat;
in
{
  options.modules.desktop.forceX11Compat = {
    enable = mkEnableOption "Force X11 backend for Electron apps (Chrome, VSCode, etc.) to avoid Wayland IME issues";
  };

  config = mkIf cfg.enable {
    # 这里可以添加其他需要 X11 兼容性的全局配置
  };
}
