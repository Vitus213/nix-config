{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostName = "hermes";
in
{
  targets.genericLinux.enable = true;

  home.sessionVariables = {
    NIXCFG_HOSTNAME = hostName;
  };

  nix.package = pkgs.nix;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.extraOptions = ''
    !include ${config.age.secrets."nix-access-tokens".path}
  '';

  # programs.ssh.matchBlocks."github.com".identityFile =
  #   "${config.home.homeDirectory}/.ssh/${hostName}";

  programs.nushell.extraConfig = lib.mkBefore ''
    source /run/user/1000/agenix/alias-for-work.nushell
  '';
}
