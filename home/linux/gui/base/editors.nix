{
  lib,
  pkgs,
  pkgs-master,
  ...
}:

let
  vscodeCliArgs = [
    # Temporary stability workaround under niri:
    # keep VSCode on X11 backend to avoid Wayland event-buffer crashes.
    "--ozone-platform=x11" # 强制为x11输入法能正常显示输入法候选框，不会出现偏移

    # https://code.visualstudio.com/docs/configure/settings-sync#_recommended-configure-the-keyring-to-use-with-vs-code
    # For use with any package that implements the Secret Service API
    # (for example gnome-keyring, kwallet5, KeepassXC)
    "--password-store=gnome-libsecret"
  ];
in
{
  home.packages = [
    pkgs-master.code-cursor
    # pkgs-master.zed-editor
    # pkgs-master.antigravity-fhs
  ];

  programs.vscode = {
    enable = true;
    package = pkgs-master.vscode.override {
      commandLineArgs = vscodeCliArgs;
    };
    profiles.default.userSettings = {
      "files.autoSave" = "afterDelay";
    };
  };
}
