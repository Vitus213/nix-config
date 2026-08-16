{ pkgs, ... }:
{
  home.packages =
    with pkgs;
    (lib.optionals pkgs.stdenv.isx86_64 [
      # https://joplinapp.org/help/
      joplin # joplin-cli
      # joplin-desktop
      obsidian
      notion
      apostrophe # GTK4 Wayland 原生 Markdown 编辑器，替代闭源 Typora
    ]);
}
