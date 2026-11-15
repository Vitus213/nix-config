{ pkgs, ... }:
let
  shellAliases = {
    "zj" = "zellij";
  };
in
{
  programs.zellij = {
    enable = true;
    package = pkgs.zellij;
  };
  xdg.configFile."zellij/config.kdl".source = ./config.kdl;
  # Disable catppuccin to avoid conflict with my non-nix config.
  catppuccin.zellij.enable = false;

  # auto start zellij in nushell
  programs.nushell.extraConfig = ''
    # auto start zellij
    # except when in emacs, zellij itself, herdr panes, or kitty
    # herdr injects HERDR_ENV; nested multiplexer hides agents from herdr detection
    # keep kitty bare for OSC 5522 clipboard image paste
    if $nu.is-interactive and (is-terminal --stdin) and (is-terminal --stdout) and (not ("ZELLIJ" in $env)) and (not ("INSIDE_EMACS" in $env)) and (not ("HERDR_ENV" in $env)) and (not ("KITTY_WINDOW_ID" in $env)) {
      if "ZELLIJ_AUTO_ATTACH" in $env and $env.ZELLIJ_AUTO_ATTACH == "true" {
        ^zellij attach -c
      } else {
        ^zellij
      }
    }
  '';

  # only works in bash/zsh, not nushell
  home.shellAliases = shellAliases;
  programs.nushell.shellAliases = shellAliases;
}
