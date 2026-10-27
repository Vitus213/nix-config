{ config, lib, ... }:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  programs.nushell.extraConfig = lib.mkBefore ''
    source /etc/agenix/alias-for-work.nushell
  '';

  modules.desktop.nvidia.enable = true;
  modules.desktop.forceX11Compat.enable = true;

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink "${config.home.homeDirectory}/nix-config/hosts/olympians-athena/niri-hardware.kdl";
}
