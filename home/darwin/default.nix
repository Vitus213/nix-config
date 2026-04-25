{
  mylib,
  myvars,
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  home.homeDirectory = "/Users/${myvars.username}";
  imports = (mylib.scanPaths ./.) ++ [
    ../base/core
    ../base/tui
    ../base/gui
    ../base/home.nix
  ];

  # enable management of XDG base directories on macOS.
  xdg.enable = true;

  nix.package = pkgs.nix;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.extraOptions = lib.mkAfter ''
    !include ${osConfig.age.secrets.nix-access-tokens.path}
  '';
}
