{
  lib,
  ...
}:
with lib;
{
  options.modules.desktop.forceX11Compat = {
    enable = mkEnableOption "Force X11 backend for Electron apps (Chrome, VSCode, etc.) to avoid Wayland IME issues";
  };
}
