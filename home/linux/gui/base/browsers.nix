{
  pkgs,
  zen-browser,
  ...
}:
{
  home.packages = [
    # Zen Browser：垂直标签栏 Firefox 分支，原生 Wayland，适合大量标签页与多工作区。
    # 来自 flake input（上游每日自动更新），版本固定于 flake.lock。
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
