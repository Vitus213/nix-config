# Home Manager 共享层

`home/base/` 存放 Linux 和 macOS 都能复用的用户级配置。

## 主要目录

| 路径       | 用途                                          |
| ---------- | --------------------------------------------- |
| `core/`    | shell、git、编辑器、主题、包管理器等基础配置  |
| `gui/`     | 跨平台 GUI 应用和终端模拟器                   |
| `tui/`     | 终端应用、GPG、password-store、SSH、Zellij 等 |
| `home.nix` | 共享层入口                                    |

## 使用原则

- 能跨平台工作的配置优先放这里
- 平台专属逻辑放到 `home/linux/` 或 `home/darwin/`
- 只有一个主机使用的配置先放主机目录，确认复用后再提升到共享层
