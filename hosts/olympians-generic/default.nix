{
  lib,
  pkgs,
  ...
}:
#############################################################
#
#  Generic - reusable NixOS desktop host without private secrets or preservation.
#
#############################################################
let
  hostName = "generic"; # Define your hostname.
in
{
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # ./nvidia.nix
    ./generic

    # ./preservation.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_7_0;

  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  # Zram consumes physical memory for compression, which can cause a deadlock and system hang if the model size approaches the physical memory limit.
  zramSwap.enable = lib.mkForce false;

  services.sunshine.enable = lib.mkForce true;
  services.tuned.ppdSettings.main.default = lib.mkForce "performance";

  nix.extraOptions = lib.mkForce ''
    builders-use-substitutes = true
  '';

  networking = {
    inherit hostName;

    networkmanager.enable = true; # provides nmcli/nmtui for wifi adjustment
    useDHCP = lib.mkDefault true;
  };

  networking.useNetworkd = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
