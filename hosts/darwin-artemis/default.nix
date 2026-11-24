{
  lib,
  mysecrets,
  myvars,
  pkgs,
  ...
}:
let
  hostname = "artemis";
in
{
  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  homebrew.onActivation = {
    autoUpdate = lib.mkForce false;
    upgrade = lib.mkForce false;
  };

  environment.systemPackages = with pkgs; [
    colima
    docker
    (callPackage ./flclash.nix { })
  ];

  age.secrets.flclash-subscriptions = {
    file = "${mysecrets}/flclash-artemis-subscriptions.json.age";
    mode = "0400";
    owner = myvars.username;
  };

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
