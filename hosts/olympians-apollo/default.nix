{
  lib,
  pkgs,
  refind-minimal,
  ...
}:
#############################################################
#
#  Apollo - my main computer, with NixOS + AMD Ryzen 5 5600 + RTX 3070 LHR GPU, for daily use.
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
  # NixOS 模块只安装 refind_x64.efi；补上官方 icons/，主题缺的图标会回退到这里
  refindStockIcons = pkgs.refind + "/share/refind/icons";
  refindStockIconFiles = lib.mapAttrs' (
    name: _: lib.nameValuePair "icons/${name}" (refindStockIcons + "/${name}")
  ) (builtins.readDir refindStockIcons);
in
{
  imports = [
    ../_shared/netdev-mount.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../_shared/nvidia.nix

    ../_shared/preservation.nix
  ];

  # 固定到 LTS 系列：非 LTS 内核 EOL 后会被 nixpkgs 直接删除，导致求值失败
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  # Match Windows' default RTC behavior for dual boot.
  time.hardwareClockInLocalTime = true;

  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = false;
    refind = {
      enable = true;
      maxGenerations = 1;
      # 内联 rEFInd-minimal 的 theme.conf，去掉 hideui 里的 label 以显示选中项文字
      extraConfig = ''
        hideui singleuser,hints,arrows,badges
        icons_dir themes/rEFInd-minimal/icons
        banner themes/rEFInd-minimal/background.png
        banner_scale fillscreen
        selection_big themes/rEFInd-minimal/selection_big.png
        selection_small themes/rEFInd-minimal/selection_small.png
        showtools shutdown
        scanfor manual

        # Keep this as the only manual boot entry before generated NixOS entries.
        # The NixOS rEFInd module appends default_selection 2, so the second item is NixOS.
        menuentry "Windows" {
          icon /EFI/refind/themes/rEFInd-minimal/icons/os_win.png
          volume 8de23719-2dee-4179-a6c4-033a2f39df32
          loader /EFI/Microsoft/Boot/bootmgfw.efi
        }
      '';
      additionalFiles = refindStockIconFiles // refindMinimalThemeFiles;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  # Zram consumes physical memory for compression, which can cause a deadlock and system hang if the model size approaches the physical memory limit.
  zramSwap.enable = false;

  services.sunshine.enable = true;
  services.tuned.ppdSettings.main.default = "performance";

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
