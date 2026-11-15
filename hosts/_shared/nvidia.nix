{
  lib,
  ...
}:
{
  # ===============================================================================================
  # for Nvidia GPU
  # https://wiki.nixos.org/wiki/NVIDIA
  # https://wiki.hyprland.org/Nvidia/
  # ===============================================================================================

  services.xserver.videoDrivers = [ "nvidia" ]; # will install nvidia-vaapi-driver by default
  hardware.nvidia = {
    # Open-source kernel modules are preferred over and planned to steadily replace proprietary modules
    open = true;
    nvidiaSettings = true;

    powerManagement.enable = true;

    # dynamicBoost / nvidia-powerd is primarily for supported laptop platforms.
    # On many desktops it fails with "Allocate Root client failed 0x6a" and blocks switch.
    dynamicBoost.enable = lib.mkForce false;
  };

  hardware.nvidia-container-toolkit.enable = true;
  hardware.graphics = {
    enable = true;
    # needed by nvidia-docker
    enable32Bit = true;
  };

  services.sunshine.settings = {
    max_bitrate = 20000; # in Kbps
    # NVIDIA NVENC Encoder
    nvenc_preset = 3; # 1(fastest + worst quality) - 7(slowest + best quality)
    nvenc_twopass = "full_res"; # quarter_res / full_res.
  };
}
