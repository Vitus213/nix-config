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
    # Temporary stability workaround:
    # force Chromium/Electron to X11 to avoid niri Wayland buffer overflow crashes
    # and IME candidate misplacement on 4K fractional scaling.
    "NIXOS_OZONE_WL" = "0";
    "MOZ_ENABLE_WAYLAND" = "1"; # for firefox to run on wayland
    "MOZ_WEBRENDER" = "1";
    "ELECTRON_OZONE_PLATFORM_HINT" = "x11";
    # misc
    "_JAVA_AWT_WM_NONREPARENTING" = "1";
    "QT_WAYLAND_DISABLE_WINDOWDECORATION" = "1";
    "QT_QPA_PLATFORM" = "wayland";
    "SDL_VIDEODRIVER" = "wayland";
    "GDK_BACKEND" = "wayland";
    "XDG_SESSION_TYPE" = "wayland";
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
    # screenshot/screencast
    flameshot
    hyprshot # screen shot
    wf-recorder # screen recording
  ];

  # screen locker
  programs.swaylock.enable = true;

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
