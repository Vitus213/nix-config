# Linux 桌面基础配置

这个目录存放 Linux 图形桌面的通用 Home Manager 模块。

## 模块分类

| 文件或目录          | 用途                             |
| ------------------- | -------------------------------- |
| `noctalia/`         | Noctalia Shell 配置和用户服务    |
| `hypridle/`         | 空闲管理                         |
| `fcitx5/`           | Fcitx5 输入法                    |
| `gtk.nix`           | GTK 主题                         |
| `xdg/`              | XDG 文件关联和 autostart         |
| `browsers.nix`      | 浏览器                           |
| `desktop-tools.nix` | 日常桌面工具                     |
| `dev-tools.nix`     | GUI 开发工具                     |
| `editors.nix`       | GUI 编辑器                       |
| `media.nix`         | 媒体应用                         |
| `voice-input.nix`   | Voxtype 语音输入                 |
| `gaming.nix`        | 游戏相关应用                     |
| `creative.nix`      | 创作软件                         |
| `note-taking.nix`   | 笔记应用                         |
| `misc.nix`          | Wayland 工具、截图、录屏、音频等 |
| `nvidia.nix`        | NVIDIA 相关用户级配置            |

## Noctalia Shell

Noctalia Shell 当前承担桌面 shell 的主要职责，替代或整合了部分传统工具:

| 传统工具    | 作用     | Noctalia 对应能力 |
| ----------- | -------- | ----------------- |
| `gammastep` | 夜间色温 | `nightLight`      |
| `swaylock`  | 锁屏     | 内置锁屏          |
| `anyrun`    | 启动器   | `appLauncher`     |
| `mako`      | 通知     | `notifications`   |
| `waybar`    | 状态栏   | `bar`             |
| `wlogout`   | 会话菜单 | `sessionMenu`     |

主配置在 `noctalia/config/settings.json`。

## 参考

- <https://docs.noctalia.dev/docs>
- [上级目录说明](../README.md)
