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

    # "${pkgs.clash-verge-rev}/share/applications/clash-verge.desktop"

    # 默认浏览器 Zen（替代原 nixpaks.firefox 条目）；desktop 文件随 flake input 提供，
    # Exec=zen --name zen %U，zen 二进制在用户 profile PATH 中。
    "${zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/applications/zen.desktop"
    "${pkgs.bwraps.wechat}/share/applications/wechat.desktop"
  ]
  ++ lib.optionals pkgs.stdenv.isx86_64 [
    "${pkgs.obsidian}/share/applications/obsidian.desktop"
    "${pkgs.typora}/share/applications/typora.desktop"
  ];
  # ++ (
  #   if pkgs.stdenv.isx86_64 then
  #     [ "${pkgs.google-chrome}/share/applications/google-chrome.desktop" ]
  #   else
  #     [ "${pkgs.chromium}/share/applications/chromium-browser.desktop" ]
  # );
}
