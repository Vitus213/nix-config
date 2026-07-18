{
  lib,
  config,
  pkgs,
  type4me-linux,
  ...
}:

let
  type4mePackage = type4me-linux.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = [
    type4mePackage
    pkgs.wtype
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.playerctl
  ];

  systemd.user.services.type4me-linux = {
    Unit = {
      Description = "Type4Me resident voice input application";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };

    Service = {
      ExecStart = "${lib.getExe type4mePackage} gui --background";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 20;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
