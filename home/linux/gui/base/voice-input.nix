{
  lib,
  config,
  pkgs,
  type4me,
  ...
}:
let
  type4mePackage = type4me.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = [
    type4mePackage
  ];

  # Type4Me 常驻语音输入服务；窗口规则与快捷见
  # home/linux/gui/niri/conf/keybindings.kdl（D-Bus Toggle/Cancel）。
  systemd.user.services.type4me-linux = {
    Unit = {
      Description = "type4me-linux 常驻语音输入服务";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };

    Service = {
      ExecStart = "${lib.getExe type4mePackage} service";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 20;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
