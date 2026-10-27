{
  config,
  lib,
  modulesPath,
  ...
}:
# 来自 athena 上 nixos-generate-config 的结果（MS-H610M + i5-12400F + RTX 4060）。
# 与 Windows 共用 nvme0n1：nvme0n1p1 是 Windows 原有的 300M ESP，nvme0n1p5 是 NixOS 根分区。
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/fdba9ad4-a172-446a-9306-c94f8d9c8dd9";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/E394-2F85";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # Intel CNVi WiFi / 蓝牙（iwlwifi、btintel）需要 linux-firmware
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
