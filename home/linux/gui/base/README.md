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
| `voice-input.nix`   | Type4Me 语音输入                        |
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

Noctalia 从本机私有目录 `~/Pictures/WLOP`
递归读取壁纸，当前每 600 秒为所有显示器随机切换，并从壁纸生成 Shell 配色。该目录不由 Nix、Home
Manager 或 Git 管理；每台桌面主机都需要从 WLOP 官方渠道单独准备图片。当前筛选作品的标题、官方页面和预期文件名记录在公开的
[Vitus213/wallpapers](https://github.com/Vitus213/wallpapers)，仓库不保存原图。

新增或恢复壁纸时，将合法取得的文件复制到 `~/Pictures/WLOP`，再通过 Noctalia 壁纸选择器或
`noctalia-shell ipc call wallpaper set <path> all` 应用。需要更换目录时修改
`noctalia/config/settings.json` 的 `wallpaper.directory`；回滚时恢复该字段并重新选择目标图片。

Noctalia Shell 由 Home Manager 的 `noctalia-shell.service` 用户服务启动。服务设置了
`NOCTALIA_PAM_SERVICE=noctalia-lock`，锁屏认证使用专用的精简 PAM 服务
`/etc/pam.d/noctalia-lock`（定义在
`modules/nixos/desktop/security.nix`），只做一次 pam_unix 校验，避免默认 `login`
栈的多次哈希验证导致解锁等待约 10 秒。该服务不运行 session 阶段，锁屏时不再顺带解锁 gnome-keyring；登录时 greetd 已负责解锁，会话内不受影响。背景与验证见
[documents/lockscreen-pam.md](../../../../documents/lockscreen-pam.md)。

锁屏由 `hypridle` 触发 `noctalia-shell ipc call lockScreen lock`。

### 壁纸来源

Noctalia Shell `4.4.3` 从 `/home/vitus/Pictures/Wallpapers` 递归读取壁纸，路径由
`noctalia/config/settings.json` 的 `wallpaper.directory` 固定。Home Manager 将该目录链接到非 flake
input `github:Vitus213/wallpapers` 的 `jpg/` 子目录；`flake.lock`
固定具体提交，只向壁纸选择器暴露 JPG 文件，不暴露壁纸仓库的 `README.md` 和 `sources.json`。

新增或替换壁纸时先更新 `Vitus213/wallpapers` 的 `jpg/` 目录，再更新本仓库的 `wallpapers`
锁定版本并部署配置。当前 `automationEnabled` 为 `false`，不会按间隔自动切换壁纸。回滚时可将
`wallpapers.url` 和 `home.file."Pictures/Wallpapers".source` 改回其他壁纸仓库及其图片子目录。

## Orca

`misc.nix` 通过 `pkgs.stably-orca` 安装 StablyAI Orca `1.4.137`，启动命令为
`orca`。`xdg/autostart.nix` 让 Orca 在登录 Niri 图形会话后自动启动；Niri 会将窗口默认打开到 `5code`
工作区并最大化。版本固定、自启动、更新和回滚方式见 [Orca 桌面应用](../../../../documents/orca.md)。

## 空闲策略

`hypridle` 当前按以下顺序处理空闲动作：

- 3 分钟：关闭键盘背光，恢复活动后还原键盘背光。
- 20 分钟：调用 Noctalia 锁屏。
- 20 分 30 秒：通过 `niri msg action power-off-monitors` 关闭显示器，恢复活动后重新打开显示器。

## 参考

- <https://docs.noctalia.dev/v4/>
- [上级目录说明](../README.md)
