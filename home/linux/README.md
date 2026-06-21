# Linux Home Manager 配置

这个目录存放 Linux 专用的用户级配置。

## 入口

- `core.nix`: Linux 基础配置
- `tui.nix`: 终端环境配置
- `gui.nix`: 完整图形桌面入口

## 子目录

- `base/`: Linux 基础工具、shell、命令行工具
- `gui/`: 桌面环境、Wayland、niri、Noctalia Shell 和 GUI 应用

## 使用建议

- 只需要终端环境时使用 `tui.nix`
- 桌面系统使用 `gui.nix`
- 和窗口管理器、输入法、通知、锁屏、启动器相关的配置优先放在 `gui/`
