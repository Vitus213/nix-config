{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.delta-zed ];

  programs.nushell.extraConfig = lib.mkBefore ''
    source /run/agenix/alias-for-work.nushell
  '';
}
