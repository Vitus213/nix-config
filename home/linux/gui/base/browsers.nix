{
  config,
  lib,
  pkgs,
  zen-browser,
  ...
}:
let
  forceX11 = config.modules.desktop.forceX11Compat.enable;
in
{
  home.packages = [
    # Zen Browser：垂直标签栏 Firefox 分支，原生 Wayland，适合大量标签页与多工作区。
    # 来自 flake input（上游每日自动更新），版本固定于 flake.lock。
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Google Chrome：第二浏览器，也用来打开 Notion / Linear 网页 App（见 work-apps.nix）。
    # 与 editors.nix 一致：forceX11Compat 开启时走 X11，Fcitx 候选框不会偏移。
    (pkgs.google-chrome.override {
      commandLineArgs = lib.concatStringsSep " " (lib.optionals forceX11 [ "--ozone-platform=x11" ]);
    })
  ];
}
