{
  pkgs,
  config,
  lib,
  myvars,
  ...
}:
with lib;
let
  cfgWayland = config.modules.desktop.wayland;
in
{
  imports = [
    ./base
    ../base
    ./desktop
  ];

  options.modules.desktop = {
    wayland = {
      enable = mkEnableOption "Wayland Display Server";
    };
  };

  config = mkMerge [
    (mkIf cfgWayland.enable {
      ####################################################################
      #  NixOS's Configuration for Wayland based Window Manager
      ####################################################################
      services = {
        xserver.enable = false; # disable xorg server
        # https://wiki.archlinux.org/title/Greetd
        greetd = {
          enable = true;
          settings = {
            default_session = {
              # Keep a login-capable fallback session after logout.
              user = myvars.username;
              command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd $HOME/.wayland-session";
            };

            # Use initial_session for auto-login so the running desktop is a regular user
            # session rather than a greeter session (required for lock-session support).
            initial_session = {
              user = myvars.username;
              command = "$HOME/.wayland-session";
            };
          };
        };
      };

      # fix https://github.com/ryan4yin/nix-config/issues/10
      security.pam.services.swaylock = { };
    })
  ];
}
