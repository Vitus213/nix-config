{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    nixpaks.firefox
  ];

  # source code: https://github.com/nix-community/home-manager/blob/master/modules/programs/chromium.nix
  programs.google-chrome = {
    enable = true;
    package = if pkgs.stdenv.isAarch64 then pkgs.chromium else pkgs.google-chrome;
    # Keep Chrome on X11 backend to avoid Wayland IME candidate misplacement.
    commandLineArgs = [
      "--ozone-platform=x11"
      "--ozone-platform-hint=x11"
      # X11 under Wayland doesn't pick compositor fractional scale reliably.
      # Match DP-1 scale=1.5 to avoid tiny top bar/address bar on 4K.
      "--force-device-scale-factor=1.5"
      "--high-dpi-support=1"
    ];
  };
}
