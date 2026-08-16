{
  lib,
  config,
  pkgs,
  syllune,
  ...
}:
let
  syllunePackage = syllune.packages.${pkgs.stdenv.hostPlatform.system}.syllune;
in
{
  home.packages = [
    syllunePackage
    # overlay pill：eww daemon 常驻 + overlay pump 的 python3 解释器
    pkgs.eww
    pkgs.python3
  ];

  systemd.user.services.eww-syllune-overlay = {
    Unit = {
      Description = "eww daemon for the Syllune streaming overlay";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };

    Service = {
      ExecStart = "${lib.getExe pkgs.eww} daemon";
      Restart = "on-failure";
      RestartSec = 3;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };

  systemd.user.services.syllune-web = {
    Unit = {
      Description = "Syllune history web console";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };

    Service = {
      ExecStart = "${lib.getExe syllunePackage} history serve";
      Restart = "on-failure";
      RestartSec = 3;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
