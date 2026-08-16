{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    # GUI apps
    # e-book viewer(.epub/.mobi/...)
    # do not support .pdf
    foliate

    # AI agent orchestration desktop app
    stably-orca

    # remote desktop(rdp connect)
    remmina
    freerdp # required by remmina

    # my custom hardened packages
    nixpaks.qq
    nixpaks.telegram-desktop
    # qqmusic
    bwraps.wechat
    # Keep Feishu on XWayland, but route screen sharing through portal/PipeWire.
    (feishu.override {
      commandLineArgs = "--enable-features=WebRTCPipeWireCapturer";
    })
    # discord # update too frequently, use the web version instead
  ];

  # allow fontconfig to discover fonts and configurations installed through home.packages
  # Install fonts at system-level, not user-level
  fonts.fontconfig.enable = false;
}
