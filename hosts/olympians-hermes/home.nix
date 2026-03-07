{ config, lib, ... }:
let
  hostName = "hermes";
in
{
  targets.genericLinux.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";

  programs.nushell.extraConfig = lib.mkBefore ''
    source /run/user/1000/agenix/alias-for-work.nushell
  '';
}
