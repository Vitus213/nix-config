{ lib, pkgs, ... }:
let
  routes = pkgs.writeText "notification-workspaces.json" (
    builtins.toJSON {
      "1terminal" = [
        "omp"
        "herdr"
      ];
      "6chat" = [
        "slack"
        "wechat"
        "weixin"
        "微信"
        "com.tencent.WeChat"
        "org.telegram.desktop"
        "telegram"
        "feishu"
        "飞书"
        "lark"
        "qq"
      ];
    }
  );
  bridge = pkgs.writeShellApplication {
    name = "noctalia-notification-alerts";
    runtimeInputs = with pkgs; [
      systemd
      niri
      noctalia
    ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./notification-alerts.py} ${routes}
    '';
  };
in
{
  systemd.user.services.noctalia-notification-alerts = {
    Unit = {
      Description = "Notification workspace dots";
      After = [ "noctalia.service" ];
      PartOf = [ "noctalia.service" ];
    };
    Service = {
      ExecStart = lib.getExe bridge;
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "noctalia.service" ];
  };
}
