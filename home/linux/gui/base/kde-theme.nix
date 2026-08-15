{ pkgs, ... }:
let
  # 与仓库 Catppuccin Mocha/Pink 身份对齐的 Kvantum 主题变体
  catppuccinKvantum = pkgs.catppuccin-kvantum.override {
    accent = "pink";
    variant = "mocha";
  };
in
{
  # Kvantum 样式引擎（Qt6 插件）；Dolphin 等 Qt 应用经 QT_STYLE_OVERRIDE 使用它
  home.packages = with pkgs; [
    kdePackages.qtstyleplugin-kvantum
  ];

  home.sessionVariables = {
    # kdeglobals 的 widgetStyle 在非 Plasma 环境对 KDE 应用不生效，必须环境变量。
    # 影响所有 Qt widget 应用（noctalia 为 QML，影响有限）。
    "QT_STYLE_OVERRIDE" = "kvantum";
  };

  xdg.configFile = {
    # 官方 catppuccin/nix HM 模块同款布局：主题放 ~/.config/Kvantum/
    "Kvantum/catppuccin-mocha-pink".source = "${catppuccinKvantum}/share/Kvantum/catppuccin-mocha-pink";
    "Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=catppuccin-mocha-pink
    '';
    # KDE 应用配置：图标用已安装的 Catppuccin 重着色 Papirus
    "kdeglobals".text = ''
      [Icons]
      Theme=Papirus-Dark

      [KDE]
      widgetStyle=kvantum
    '';
  };
}
