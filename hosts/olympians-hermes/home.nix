{ config, lib, ... }:
let
  hostName = "hermes";
in
{
  targets.genericLinux.enable = true;

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/${hostName}";

  programs.nushell.extraConfig = lib.mkBefore ''
    if ("${config.age.secrets."alias-for-work.nushell".path}" | path exists) {
      source ${config.age.secrets."alias-for-work.nushell".path}
    }
  '';
}
