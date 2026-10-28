{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [ pkgs.magpie ];

  # 单实例网关仅绑定 Athena 的 LAN IP；管理页面留在回环地址。
  systemd.user.services.magpie = {
    Unit = {
      Description = "Magpie shared LAN AI model gateway";
      Documentation = [ "https://github.com/yetone/magpie/blob/v0.1.1846/docs/reference.md" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.magpie} serve --web=127.0.0.1:3430";
      EnvironmentFile = "${config.xdg.configHome}/magpie/web.env";
      Restart = "on-failure";
      RestartSec = 3;
      UMask = "0077";
      Environment = [
        "MAGPIE_ADDR=0.0.0.0:3425"
        "DO_NOT_TRACK=1"
        "PATH=${config.home.homeDirectory}/.cache/.bun/bin:${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.npm/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };
}
