{
  lib,
  pkgs,
  refind-minimal,
  ...
}:
#############################################################
#
#  Apollo - my main computer, with NixOS + AMD Ryzen 5 5600 + RTX 3070 LHR GPU, for gaming & daily use.
#
#############################################################
let
  hostName = "apollo"; # Define your hostname.
  refindMinimalTheme = refind-minimal;
  refindMinimalFiles = lib.filesystem.listFilesRecursive refindMinimalTheme;
  refindMinimalThemeFiles =
    (builtins.listToAttrs (
      map (path: {
        name = builtins.unsafeDiscardStringContext (
          "themes/rEFInd-minimal/${lib.removePrefix "${refindMinimalTheme}/" (toString path)}"
        );
        value = path;
      }) refindMinimalFiles
    ))
    // {
      "themes/rEFInd-minimal/icons/os_linux.png" = refindMinimalTheme + "/icons/os_nixos.png";
    };
in
{
  imports = [
    ./netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./nvidia.nix
    ./apollo

    ./preservation.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_7_0;

  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = false;
    refind = {
      enable = true;
      maxGenerations = 1;
      extraConfig = ''
        include themes/rEFInd-minimal/theme.conf
        scanfor manual

        # Keep this as the only manual boot entry before generated NixOS entries.
        # The NixOS rEFInd module appends default_selection 2, so the second item is NixOS.
        menuentry "Windows" {
          icon /EFI/refind/themes/rEFInd-minimal/icons/os_win.png
          volume 8de23719-2dee-4179-a6c4-033a2f39df32
          loader /EFI/Microsoft/Boot/bootmgfw.efi
        }
      '';
      additionalFiles = refindMinimalThemeFiles;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  # Zram consumes physical memory for compression, which can cause a deadlock and system hang if the model size approaches the physical memory limit.
  zramSwap.enable = lib.mkForce false;

  services.sunshine.enable = lib.mkForce true;
  services.tuned.ppdSettings.main.default = lib.mkForce "performance";

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
