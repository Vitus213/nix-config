{
  pkgs,
  config,
  lib,
  zen-browser,
  ...
}:
let
  cfg = config.modules.desktop.forceX11Compat;
in
{
  home.packages = with pkgs; [
    nixpaks.firefox
    # Zen Browser：垂直标签栏 Firefox 分支，原生 Wayland，适合大量标签页与多工作区。
    # 来自 flake input（上游每日自动更新），版本固定于 flake.lock。
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # source code: https://github.com/nix-community/home-manager/blob/master/modules/programs/chromium.nix
  programs.google-chrome = {
    enable = true;
    package = if pkgs.stdenv.isAarch64 then pkgs.chromium else pkgs.google-chrome;
    # Keep Chrome on X11 backend to avoid Wayland IME candidate misplacement.
    commandLineArgs = [

      "--high-dpi-support=1"
    ]
    ++ lib.optionals cfg.enable [
      "--ozone-platform=x11"
      "--ozone-platform-hint=x11"
      # X11 under Wayland doesn't pick compositor fractional scale reliably.
      # Match DP-1 scale=1.5 to avoid tiny top bar/address bar on 4K.
      "--force-device-scale-factor=1.5"
    ];
  };
}
