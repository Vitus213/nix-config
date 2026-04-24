{
  mylib,
  myvars,
  lib,
  osConfig,
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

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.extraOptions = lib.mkAfter ''
    !include ${osConfig.age.secrets.nix-access-tokens.path}
  '';
}
