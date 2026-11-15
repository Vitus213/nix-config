{
  pkgs,
  config,
  ...
}:
{
  # wayland related
  home.sessionVariables = {
    BROWSER = "zen";
    WINEPREFIX = "${config.xdg.dataHome}/wine";
    # Keep Zen (firefox-based) on Wayland.
    # Electron backend is no longer forced globally; set per app instead.
    "MOZ_ENABLE_WAYLAND" = "1"; # for zen/firefox-based browsers to run on wayland
    "MOZ_WEBRENDER" = "1";
    # misc
    "_JAVA_AWT_WM_NONREPARENTING" = "1";
    "QT_WAYLAND_DISABLE_WINDOWDECORATION" = "1";
    "QT_QPA_PLATFORM" = "wayland";
    "SDL_VIDEODRIVER" = "wayland";
    "GDK_BACKEND" = "wayland";
    "XDG_SESSION_TYPE" = "wayland";
    # GTK4 Vulkan renderer crashes on NVIDIA (VK_ERROR_OUT_OF_DATE_KHR);
    # force GL backend for GTK4 apps (foliate, remmina, ...).
    "GSK_RENDERER" = "gl";
    # Force Catppuccin GTK theme for GTK apps; pairs with gtk.theme in
    # home/base/core/theme.nix.
    "GTK_THEME" = "catppuccin-mocha-pink-standard+rimless";
  };

  home.packages = with pkgs; [
    fuzzel # dmenu-style launcher used by TOTP selector
    wl-clipboard # copying and pasting
    hyprpicker # color picker
    brightnessctl
    # audio
    alsa-utils # provides amixer/alsamixer/...
    networkmanagerapplet # provide GUI app: nm-connection-editor
    virt-viewer # remote VM console, including KubeVirt
  ];

  services.udiskie.enable = true;
}
