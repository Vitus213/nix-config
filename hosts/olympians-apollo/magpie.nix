{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [ pkgs.magpie ];

  # 网关常驻；管理界面按需运行 magpie web，不在 unit 或 store 中存管理密钥。
  systemd.user.services.magpie = {
    Unit = {
      Description = "Magpie local AI model gateway";
      Documentation = [ "https://github.com/yetone/magpie/blob/v0.1.1846/docs/reference.md" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.magpie} serve";
      Restart = "on-failure";
      RestartSec = 3;
      UMask = "0077";
      Environment = [
        "MAGPIE_ADDR=127.0.0.1:3425"
        "DO_NOT_TRACK=1"
        "PATH=${config.home.homeDirectory}/.cache/.bun/bin:${config.home.homeDirectory}/.local/bin:${config.home.homeDirectory}/.npm/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
    };
    Install.WantedBy = [ "default.target" ];
  };
}
