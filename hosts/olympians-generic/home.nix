{ config, lib, ... }:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  # programs.ssh.matchBlocks."github.com".identityFile =
  #   "${config.home.homeDirectory}/.ssh/vitus-generic";

  # No private agenix secrets are enabled for this reusable host.
  programs.nushell.extraConfig = lib.mkBefore "";

  modules.desktop.nvidia.enable = false;
  modules.desktop.forceX11Compat.enable = false;

  # Drop the homelab `192.168.*` block: its IdentityFile /etc/agenix/ssh-key-romantic
  # does not exist on this secret-free host (the old `matchBlocks` mkForce targeted
  # a different option than the base module uses, so it never took effect).
  modules.ssh.homelab.enable = false;
  home.activation.configureGhAuth = lib.mkForce "";
  xdg.configFile."agenix/github_token".enable = lib.mkForce false;
  xdg.configFile."totp/secrets.conf".enable = lib.mkForce false;

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink "${config.home.homeDirectory}/nix-config/hosts/olympians-generic/niri-hardware.kdl";
}
