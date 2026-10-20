{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.desktop.workApps;
  webappsDir = "${config.home.homeDirectory}/.local/share/webapps";

  # Notion / Linear 没有官方 Linux 客户端，用 Chrome（browsers.nix 安装）的 --app 模式打开官方网页：
  # - 独立 user-data-dir：每个 App 单独进程与登录态，--class 才会生效；
  # - --class：设置窗口的 app-id，供 niri 窗口规则匹配（见 niri/conf/windowrules.kdl）。
  mkWebApp =
    {
      id,
      name,
      url,
      categories,
    }:
    {
      inherit name categories;
      exec = "google-chrome-stable --user-data-dir=${webappsDir}/${id} --class=${id} --app=${url}";
      icon = "web-browser";
      terminal = false;
      settings.StartupWMClass = id;
    };
in
{
  options.modules.desktop.workApps = {
    enable = lib.mkEnableOption "work collaboration apps: Slack, plus Notion and Linear as Chrome web apps";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.slack # 官方客户端；未设置 NIXOS_OZONE_WL 时默认走 X11
    ];

    # 登录后自启动 Slack；与 xdg/autostart.nix 的条目列表合并
    xdg.autostart.entries = [ "${pkgs.slack}/share/applications/slack.desktop" ];

    xdg.desktopEntries = {
      notion = mkWebApp {
        id = "notion";
        name = "Notion";
        url = "https://www.notion.so";
        categories = [
          "Office"
          "Network"
        ];
      };
      linear = mkWebApp {
        id = "linear";
        name = "Linear";
        url = "https://linear.app";
        categories = [
          "Development"
          "ProjectManagement"
          "Network"
        ];
      };
    };
  };
}
