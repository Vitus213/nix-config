{
  pkgs,
  lib,
  zen-browser,
  ...
}:
{
  # XDG autostart entries - ensures apps start after portal services are ready
  xdg.autostart.enable = true;
  # This fixes nixpak sandboxed apps accessing mapped folders correctly
  xdg.autostart.entries = [
    "${pkgs.foot}/share/applications/foot.desktop"
    "${pkgs.alacritty}/share/applications/Alacritty.desktop"

    "${pkgs.stably-orca}/share/applications/orca.desktop"

    # FlClash 不随登录自启动（应用内管理），需要时手动启动。
    # 旧 clash-verge-rev 条目已随移除删除。

    # 默认浏览器 Zen；desktop 文件随 flake input 提供，
    # Exec=zen --name zen %U，zen 二进制在用户 profile PATH 中。
    "${zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/applications/zen.desktop"
    "${pkgs.bwraps.wechat}/share/applications/wechat.desktop"
  ]
  ++ lib.optionals pkgs.stdenv.isx86_64 [
    "${pkgs.obsidian}/share/applications/obsidian.desktop"
    "${pkgs.apostrophe}/share/applications/org.gnome.gitlab.somas.Apostrophe.desktop"
  ];
}
