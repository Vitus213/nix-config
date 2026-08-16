{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.modules.desktop.forceX11Compat;

  vscodeCliArgs =
    [ ]
    ++ lib.optionals cfg.enable [
      # Temporary stability workaround under niri:
      # keep VSCode on X11 backend to avoid Wayland event-buffer crashes.
      "--ozone-platform=x11" # 强制为x11输入法能正常显示输入法候选框，不会出现偏移
    ]
    ++ [
      # https://code.visualstudio.com/docs/configure/settings-sync#_recommended-configure-the-keyring-to-use-with-vs-code
      # For use with any package that implements the Secret Service API
      # (for example gnome-keyring, kwallet5, KeepassXC)
      "--password-store=gnome-libsecret"
    ];
in
{
  home.packages = [
    pkgs.code-cursor
    pkgs.zed-editor
    # pkgs.antigravity-fhs
    pkgs.libreoffice-fresh # 开源办公套件，Wayland 原生，替代闭源 WPS
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.override {
      commandLineArgs = vscodeCliArgs;
    };
    # profiles.default.userSettings = {
    #   "files.autoSave" = "afterDelay";
    # };
  };
}
