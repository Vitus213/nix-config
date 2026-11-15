{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.modules.desktop.niri;
in
{
  options.modules.desktop.niri = {
    enable = lib.mkEnableOption "niri compositor";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      # Niri starts XWayland on demand when an X11 client connects.
      xwayland-satellite
    ];

    xdg.configFile =
      let
        mkSymlink = config.lib.file.mkOutOfStoreSymlink;
        confPath = "${config.home.homeDirectory}/nix-config/home/linux/gui/niri/conf";
      in
      {
        "niri/config.kdl".source = mkSymlink "${confPath}/config.kdl";
        "niri/keybindings.kdl".source = mkSymlink "${confPath}/keybindings.kdl";
        "niri/noctalia-shell.kdl".source = mkSymlink "${confPath}/noctalia-shell.kdl";
        "niri/windowrules.kdl".source = mkSymlink "${confPath}/windowrules.kdl";
        "niri/scripts/normalize-workspaces.sh".source =
          mkSymlink "${confPath}/scripts/normalize-workspaces.sh";
      };

    systemd.user.services.niri-flake-polkit = {
      Unit = {
        Description = "PolicyKit Authentication Agent provided by niri-flake";
        After = [
          "graphical-session.target"
        ];
        Wants = [ "graphical-session-pre.target" ];
      };
      Install.WantedBy = [ "niri.service" ];
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
        TimeoutStopSec = 10;
      };
    };

    # greetd uses this compositor-independent entry point.
    home.file.".wayland-session" = {
      source = pkgs.writeScript "init-session" ''
        # trying to stop a previous niri session
        systemctl --user is-active niri.service && systemctl --user stop niri.service
        # and then we start a new one
        /run/current-system/sw/bin/niri-session
      '';
      executable = true;
    };
  };

}
