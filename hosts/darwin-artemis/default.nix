{
  lib,
  pkgs,
  ...
}:
let
  hostname = "artemis";
in
{
  imports = [ ../../secrets/flclash.nix ];

  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  homebrew.taps = [ "chen08209/tap" ];
  homebrew.casks = [
    {
      name = "chen08209/tap/flclash";
      trusted = true;
    }
  ];

  homebrew.onActivation = {
    autoUpdate = lib.mkForce false;
    upgrade = lib.mkForce false;
  };

  environment.systemPackages = with pkgs; [
    colima
    docker
  ];

  # Start the existing Colima profile on login for its persistent Redis container.
  launchd.user.agents.colima.serviceConfig = {
    ProgramArguments = [
      "${pkgs.colima}/bin/colima"
      "start"
    ];
    RunAtLoad = true;
    ProcessType = "Background";
    StandardOutPath = "/tmp/colima.log";
    StandardErrorPath = "/tmp/colima.log";
  };
}
