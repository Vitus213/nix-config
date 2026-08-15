{
  # GUI = TUI 全套配置 + GUI 专属层，链式继承，避免重复罗列 base 入口
  imports = [
    ./tui.nix

    ../base/gui
    ./gui
  ];
}
