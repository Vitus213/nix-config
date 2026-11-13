# Linux 桌面基础配置

这个目录存放 Linux 图形桌面的通用 Home Manager 模块。

## 模块分类

| 文件或目录          | 用途                              |
| ------------------- | --------------------------------- |
| `noctalia/`         | Noctalia Shell 配置和用户服务     |
| `hypridle/`         | 空闲管理                          |
| `fcitx5/`           | Fcitx5 输入法                     |
| `gtk.nix`           | GTK 主题                          |
| `xdg/`              | XDG 文件关联和 autostart          |
| `browsers.nix`      | 浏览器                            |
| `desktop-tools.nix` | 日常桌面工具                      |
| `dev-tools.nix`     | GUI 开发工具                      |
| `editors.nix`       | GUI 编辑器                        |
| `media.nix`         | 媒体应用                          |
| `voice-input.nix`   | Voiceless 语音输入与 overlay 服务 |
| `creative.nix`      | 创作软件                          |
| `note-taking.nix`   | 笔记应用                          |
| `misc.nix`          | 电子书、远程桌面与即时通信应用    |
| `nvidia.nix`        | NVIDIA 相关用户级配置             |

## Noctalia Shell

声明配置固定原生 Noctalia `5.5.0`，由 `noctalia.service` 用户服务启动。软件包入口是
`pkgs.noctalia`，配置与本地插件位于 `noctalia/`。apollo 已完成挂载顺序修正版的
`switch`，运行系统与开机 profile 一致；主要桌面检查和真实错误/正确密码解锁均已通过。迁移与完整回滚见
[Noctalia v5](../../../../documents/noctalia-v5.md)。

`noctalia/config/config.toml` 是仓库基础层；Home Manager 按文件链接到
`~/.config/noctalia/`。GUI 改动保存在
`~/.local/state/noctalia/settings.toml`，最后加载并覆盖基础层。服务使用
`TERMINAL=kitty`，启动的应用由独立 systemd transient service 承载。

原生 Shell 提供状态栏、通知、启动器、剪贴板、锁屏、夜间色温和会话菜单。锁屏命令是
`noctalia msg session lock`；软件包补丁固定使用专用 `/etc/pam.d/noctalia-lock`，GNOME
Keyring 继续由 greetd 登录阶段解锁。详见 [PAM 说明](../../../../documents/lockscreen-pam.md)。

壁纸目录为 `/home/vitus/Pictures/Wallpapers`，Home Manager 链接到固定 wallpapers input 的 `jpg/`
子目录。当前基础壁纸为 `dome.jpg`，递归浏览开启，自动换图关闭，Shell 从壁纸生成配色。使用
`noctalia msg wallpaper-set <path>` 换图；更新图库需更新 wallpapers input 并部署。

本地 `vitus/desktop` 插件桥接现有 TOTP 脚本与系统负载；番茄钟使用固定社区插件
`thepunkoff/pomodoro`。TOTP 密钥仍由 agenix 提供，旧番茄钟统计仅保存在本机私有备份中。

## 空闲策略

`hypridle` 当前按以下顺序处理空闲动作：

- 3 分钟：关闭键盘背光，恢复活动后还原键盘背光。
- 20 分钟：调用 Noctalia 锁屏。
- 20 分 30 秒：通过 `niri msg action power-off-monitors` 关闭显示器，恢复活动后重新打开显示器。

## 参考

- <https://github.com/noctalia-dev/noctalia/tree/v5.5.0/docs/user>
- [上级目录说明](../README.md)
