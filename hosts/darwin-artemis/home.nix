{ lib, ... }:
{
  programs.nushell.extraConfig = lib.mkBefore ''
    source /run/agenix/alias-for-work.nushell
  '';
}
