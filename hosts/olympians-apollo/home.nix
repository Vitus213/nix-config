{ config, lib, ... }:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  # programs.ssh.matchBlocks."github.com".identityFile =
  #   "${config.home.homeDirectory}/.ssh/vitus-apollo";

  programs.nushell.extraConfig = lib.mkBefore ''
    source /etc/agenix/alias-for-work.nushell
  '';

  modules.desktop.nvidia.enable = true;
  modules.desktop.forceX11Compat.enable = true;
  modules.desktop.workApps.enable = true; # Slack、Notion、Linear

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink "${config.home.homeDirectory}/nix-config/hosts/olympians-apollo/niri-hardware.kdl";
}
