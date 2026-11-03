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
    # Delta：Zed 团队的多人 agent 编码环境（thread + DeltaDB），CLI 为 delta-zed；
    # 来自官方 delta-nix flake（经 overlays/delta 改名，避免与 git-delta 冲突）。
    pkgs.delta-zed
    # pkgs.antigravity-fhs
    pkgs.libreoffice # 开源办公套件，Wayland 原生，替代闭源 WPS
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
