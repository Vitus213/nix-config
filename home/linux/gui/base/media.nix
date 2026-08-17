{
  pkgs,
  pkgs-x64,
  ...
}:
# media - control and enjoy audio/video
{
  home.packages = with pkgs; [
    # audio control
    pavucontrol
    playerctl
    pulsemixer
    imv # simple image viewer
    # Qt6 wayland + NVIDIA EGL 建上下文失败（EGL_BAD_MATCH 3009），窗口永不
    # commit；wrapper 强制 xcb 走 XWayland。名字保持 sioyek，desktop/xdg-open
    # 的 PATH 解析同样命中 wrapper。
    (pkgs.symlinkJoin {
      name = "sioyek";
      paths = [ pkgs.sioyek ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/sioyek --set QT_QPA_PLATFORM xcb
      '';
    })

    # video/audio tools
    libva-utils
    vdpauinfo
    vulkan-tools
    mesa-demos
    nvitop
    (pkgs-x64.zoom-us)
    wemeet
  ];

  programs.mpv = {
    enable = true;
    defaultProfiles = [ "gpu-hq" ];
    scripts = [ pkgs.mpvScripts.mpris ];
  };

  services = {
    playerctld.enable = true;
  };
}
