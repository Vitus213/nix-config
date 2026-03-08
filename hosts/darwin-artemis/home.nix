{ config, lib, ... }:
let
  hostName = "artemis";
in
{
  # programs.ssh.matchBlocks."github.com".identityFile =
  #   "${config.home.homeDirectory}/.ssh/${hostName}";

  programs.nushell.extraConfig = lib.mkBefore ''
    source /run/agenix/alias-for-work.nushell
  '';
}
