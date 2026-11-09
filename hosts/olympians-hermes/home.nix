{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostName = "hermes";
in
{
  targets.genericLinux.enable = true;

  # New WSL instances must not publish usage reports before explicit opt-in.
  systemd.user.timers.agent-usage-report.Install.WantedBy = lib.mkForce [ ];

  home.sessionVariables = {
    NIXCFG_HOSTNAME = hostName;
  };

  nix.package = pkgs.nix;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.extraOptions = ''
    !include ${config.age.secrets."nix-access-tokens".path}
  '';

  # programs.ssh.matchBlocks."github.com".identityFile =
  #   "${config.home.homeDirectory}/.ssh/${hostName}";

  programs.nushell.extraConfig = lib.mkBefore ''
    source /run/user/1000/agenix/alias-for-work.nushell
  '';
}
