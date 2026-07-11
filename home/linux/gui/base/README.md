# Linux 桌面基础配置

这个目录存放 Linux 图形桌面的通用 Home Manager 模块。

## 模块分类

| 文件或目录          | 用途                                    |
| ------------------- | --------------------------------------- |
| `noctalia/`         | Noctalia Shell 配置和用户服务           |
| `hypridle/`         | 空闲管理                                |
| `fcitx5/`           | Fcitx5 输入法                           |
| `gtk.nix`           | GTK 主题                                |
| `xdg/`              | XDG 文件关联和 autostart                |
| `browsers.nix`      | 浏览器                                  |
| `desktop-tools.nix` | 日常桌面工具                            |
| `dev-tools.nix`     | GUI 开发工具                            |
| `editors.nix`       | GUI 编辑器                              |
| `media.nix`         | 媒体应用                                |
| `voice-input.nix`   | Voxtype 语音输入                        |
| `gaming.nix`        | 游戏相关应用                            |
| `creative.nix`      | 创作软件                                |
| `note-taking.nix`   | 笔记应用                                |
| `misc.nix`          | Wayland 工具、截图、录屏、音频、Orca 等 |
| `nvidia.nix`        | NVIDIA 相关用户级配置                   |

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

Noctalia Shell 由 Home Manager 的 `noctalia-shell.service` 用户服务启动。当前不设置
`NOCTALIA_PAM_SERVICE`，因此 Noctalia 锁屏认证使用默认的完整 `/etc/pam.d/login` PAM 栈。

锁屏由 `hypridle` 触发 `noctalia-shell ipc call lockScreen lock`。

## Orca

`misc.nix` 通过 `pkgs.stably-orca` 安装 StablyAI Orca `1.4.134`，启动命令为
`orca`。Niri 会将 Orca 默认打开到 `5code` 工作区并最大化。版本固定、更新和回滚方式见
[Orca 桌面应用](../../../../documents/orca.md)。

## 空闲策略

`hypridle` 当前按以下顺序处理空闲动作：

- 3 分钟：关闭键盘背光，恢复活动后还原键盘背光。
- 20 分钟：调用 Noctalia 锁屏。
- 20 分 30 秒：通过 `niri msg action power-off-monitors` 关闭显示器，恢复活动后重新打开显示器。

## 参考

- <https://docs.noctalia.dev/docs>
- [上级目录说明](../README.md)
