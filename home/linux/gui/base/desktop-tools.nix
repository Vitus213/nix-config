{
  mylib,
  pkgs,
  lib,
  config,
  ...
}:
{
  # wayland related
  home.sessionVariables = {
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
    # force GL backend for GTK4 apps (foliate, remmina, wlogout, ...).
    "GSK_RENDERER" = "gl";
    # Force Catppuccin GTK theme for GTK apps; pairs with gtk.theme in
    # home/base/core/theme.nix.
    "GTK_THEME" = "catppuccin-mocha-pink-standard+rimless";
  };

  home.packages = with pkgs; [
    swaybg # the wallpaper
    fuzzel # dmenu-style launcher used by TOTP selector
    wl-clipboard # copying and pasting
    hyprpicker # color picker
    brightnessctl
    # audio
    alsa-utils # provides amixer/alsamixer/...
    networkmanagerapplet # provide GUI app: nm-connection-editor
    # screenshot/screencast（Wayland 原生链：grim 截图、slurp 选区、satty 标注）
    grim
    slurp
    satty
    wf-recorder # screen recording
  ];

  # Logout Menu
  programs.wlogout.enable = true;

  # Home Manager switched wlogout handling from directory-level links to
  # file-level links in newer versions. Remove old managed symlink before
  # linking to avoid "mkdir ... File exists" activation failures.
  home.activation.migrateWlogoutConfig = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    wlogout_cfg_dir="${config.xdg.configHome}/wlogout"
    if [ -L "$wlogout_cfg_dir" ]; then
      target="$(readlink "$wlogout_cfg_dir" || true)"
      case "$target" in
        /nix/store/*-home-manager-files/.config/wlogout)
          rm "$wlogout_cfg_dir"
          ;;
      esac
    fi
  '';
}
