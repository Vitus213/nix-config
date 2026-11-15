{
  catppuccin,
  pkgs,
  lib,
  ...
}:

{
  # https://github.com/catppuccin/nix
  # 上游已修复 VSCode 主题的 pnpm 10 构建，直接使用其默认来源。
  imports = [
    catppuccin.homeModules.catppuccin
  ];

  catppuccin = {
    # Keep current default enrollment explicit for catppuccin/nix 27.05 semantics.
    enable = true;
    autoEnable = true;
    # one of "latte", "frappe", "macchiato", "mocha"
    flavor = "mocha";
    # one of "blue", "flamingo", "green", "lavender", "maroon", "mauve", "peach", "pink", "red", "rosewater", "sapphire", "sky", "teal", "yellow"
    accent = "pink";
  };

  # GTK 窗口主题：此前 gtk.theme 为空，Nautilus 等 GTK 应用跑 libadwaita 默认灰。
  # 与仓库 Catppuccin Mocha/Pink 身份对齐；仅 Linux（darwin 无 GTK 桌面需求）。
  # gtk4.theme 显式置 null：新版 home-manager 要求对 gtk.theme → gtk4 的隐式传播
  # 做显式决策，否则每次求值打弃用警告。
  gtk = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    theme = {
      package = pkgs.catppuccin-gtk.override {
        variant = "mocha";
        accents = [ "pink" ];
        size = "standard";
        tweaks = [ "rimless" ];
      };
      name = "catppuccin-mocha-pink-standard+rimless";
    };
    gtk4.theme = null;
  };
}
