{ config, ... }:
let
  hostName = "hermes";
in
{
  targets.genericLinux.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";
}
