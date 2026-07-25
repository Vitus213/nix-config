{ config, pkgs, ... }:
let
  ximRecovery = pkgs.writeShellApplication {
    name = "fcitx5-xim-recover";
    runtimeInputs = with pkgs; [
      gnugrep
      systemd
      xprop
    ];
    text = ''
      if ! xprop -root XIM_SERVERS 2>/dev/null | grep -q '@server=fcitx'; then
        systemctl --user restart fcitx5-daemon.service
      fi
    '';
  };
in
{
  catppuccin.fcitx5.enable = false;
  xdg.configFile = {
    "fcitx5/config" = {
      source = ./config;
      force = true;
    };
    "fcitx5/profile" = {
      source = ./profile;
      # every time fcitx5 switch input method, it will modify ~/.config/fcitx5/profile,
      # so we need to force replace it in every rebuild to avoid file conflict.
      force = true;
    };
    "fcitx5/conf/classicui.conf" = {
      source = ./classicui.conf;
      force = true;
    };
    # Disable the package autostart entry so only the Home Manager service owns Fcitx.
    "autostart/org.fcitx.Fcitx5.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Fcitx 5
      Hidden=true
    '';
    "mozc/config1.db".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/linux/gui/base/fcitx5/mozc-config1.db";
  };
  xdg.dataFile."fcitx5/rime/default.custom.yaml" = {
    source = ./default.custom.yaml;
    force = true;
  };
  # Trigger Niri's on-demand XWayland before Fcitx registers its XIM server.
  systemd.user.services.fcitx5-daemon.Service.ExecStartPre = "${pkgs.xprop}/bin/xprop -root";
  systemd.user.services.fcitx5-xim-recovery = {
    Unit = {
      Description = "Recover the Fcitx5 XIM server after XWayland restarts";
      After = [
        "graphical-session.target"
        "fcitx5-daemon.service"
      ];
      ConditionEnvironment = "DISPLAY";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${ximRecovery}/bin/fcitx5-xim-recover";
    };
  };
  systemd.user.timers.fcitx5-xim-recovery = {
    Unit = {
      Description = "Periodically verify the Fcitx5 XIM server";
      PartOf = [ "graphical-session.target" ];
    };
    Timer = {
      OnBootSec = "10s";
      OnUnitActiveSec = "10s";
      Unit = "fcitx5-xim-recovery.service";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-configtool # GUI for fcitx5
      fcitx5-gtk # gtk im module

      # Chinese
      fcitx5-rime # for Rime Ice chinese input method
      # fcitx5-chinese-addons # we use rime instead

      # Japanese
      # ctrl-i / F7 - convert to takakana
      # ctrl-u / F6 - convert to hiragana
      fcitx5-mozc-ut # Moze with UT dictionary

      # Korean
      fcitx5-hangul
    ];
  };
}
