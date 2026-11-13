# Niri 工作区与窗口分配

本文记录 NixOS 桌面在 Niri 下的工作区命名、快捷键和窗口自动分配规则。

## 当前工作区语义

| 工作区      | 语义         | 自动进入的应用                                |
| ----------- | ------------ | --------------------------------------------- |
| `1terminal` | 终端 / Agent | `kitty`、`Delta`                              |
| `2browser`  | 浏览器       | `Zen`、`Chrome`                               |
| `3docs`     | 文档笔记     | `Obsidian`、`Apostrophe`、Notion、Linear      |
| `4codex`    | Codex GUI    | `ChatGPT`、`Codex`、`Claude` 等 AI 图形客户端 |
| `5code`     | 代码编辑器   | `VSCode`、`Cursor`、`Zed`                     |
| `6chat`     | 聊天沟通     | `Slack`、`Telegram`、飞书、微信、QQ           |
| `7misc`     | 空白暂存     | 无固定分配，临时窗口随手放                    |
| `8music`    | 音乐         | QQ 音乐、网易云音乐                           |
| `9file`     | 文件/阅读    | `Foliate`、`Dux Files`、`Sioyek`              |
| `0other`    | 其他工具     | `FlClash`、`Zoom`、腾讯会议                   |

Niri 工作区名称使用小写，语义和 macOS AeroSpace 的 `1Terminal`、`2Browser`、`3Docs`、`4Codex`、
`5Code`、`6Chat`、`8Music`、`0Other` 对齐；`7misc` 是 Linux 端补充的空白暂存区，macOS
AeroSpace 暂无对应项。

Niri 是动态工作区模型，工作区的显示顺序不是静态编号。`niri msg workspaces`
左侧的数字是当前运行时index，不是工作区名字里的数字。`niri msg windows` 里的 `Workspace ID`
也是 Niri 内部 ID，不是显示序号；需要和 `niri msg -j workspaces` 里的 `id` 对照，显示顺序看
`idx`。命名工作区按配置声明顺序占据 index：三台主机的 `niri-hardware.kdl` 按 1–0 顺序声明，因此
`niri msg workspaces` 的 index 与名字前缀一一对应（`0other` 在 index
10）。运行中手动移动过工作区导致顺序漂移时，用 `Mod + Shift + 0` 调用整理脚本复位。

## 配置入口

通用 Niri 配置:

- `home/linux/gui/niri/conf/keybindings.kdl`
- `home/linux/gui/niri/conf/windowrules.kdl`
- `home/linux/gui/niri/conf/config.kdl`
- `home/linux/gui/niri/conf/scripts/normalize-workspaces.sh`

主机级输出和工作区显示器绑定:

- `hosts/olympians-apollo/niri-hardware.kdl`

Home Manager 会把这些配置链接到 `~/.config/niri/`。

## Linux 终端统一为 kitty

Linux
GUI 的终端入口统一为 kitty；macOS 配置不变。kitty 直接进入 Nushell，不自动进入 Zellij；需要时手动运行
`zj` 或 `herdr`。字体保持 Maple Mono NF CN
13pt，回滚历史保持 20000 行；剪贴板读取继续使用 kitty 默认授权确认，不自动放行。

| 入口                                                | 当前配置                      |
| --------------------------------------------------- | ----------------------------- |
| `Mod+Return`、`Mod+Shift+Return`、`Mod+Ctrl+Return` | `kitty`                       |
| 登录自启动                                          | `kitty.desktop`，只开一个窗口 |
| 系统 `xdg-terminal-exec`                            | `kitty.desktop`               |
| Noctalia 启动终端应用                               | v5 服务环境 `TERMINAL=kitty`  |
| 新窗口落点                                          | `1terminal`，最大化           |

配置入口：

- `home/base/gui/terminal/terminals.nix`：kitty；移除 foot 配置及 server 服务覆盖。
- `home/base/gui/terminal/alacritty/default.nix`：Alacritty 仅在 macOS 启用。
- `home/linux/gui/base/xdg/autostart.nix`：登录自动启动 kitty。
- `modules/nixos/desktop/xdg.nix`：系统默认终端。
- `home/linux/gui/base/noctalia/default.nix`：原生 v5 服务设置 `TERMINAL=kitty`。
- `home/base/tui/zellij/default.nix`：保留 kitty 跳过 Zellij 自动启动的条件。

Niri 与 Noctalia 配置通过仓库外部链接使用；Niri 快捷键与窗口规则保存后热加载。软件包移除、foot 服务移除、系统默认终端和登录自启动变更需要执行
`just local`
部署，自启动在下次登录生效。不要为迁移直接关闭现有 foot 窗口或停止承载任务的服务；旧会话不会自动迁移到 kitty，先结束或保存其中的任务。

验证：`niri validate`、`just test`；实际启动 kitty，检查 Nushell 提示符、窗口 app-id 为 `kitty`
且位于 `1terminal`。这不等于验证了 SSH 图片粘贴端到端链路。SSH terminfo 与图片粘贴说明见
[终端说明](../home/base/gui/terminal/README.md)。

回滚：恢复上述配置入口到需要的终端选择，同步恢复快捷键、窗口规则、启动器命令和自启动项，再执行
`just local`；不要仅改快捷键而遗漏软件包与默认终端。

## 文件管理器：Dux Files

Linux 图形文件管理器使用 Dux Files `2.1.2`，命令为
`dfiles`；Dolphin、Thunar 和配套 Ark 不再安装。终端文件管理器 Yazi 保留，通过 `yy`
使用。Dux 自带压缩、解压和预览功能，网络位置、手机和磁盘继续通过现有 GVfs、UDisks2 接入。

| 入口                   | 当前行为                                   |
| ---------------------- | ------------------------------------------ |
| `Mod+Shift+E`          | 显示 Dux Files                             |
| 应用启动器中的 Files   | `dfiles open`                              |
| `xdg-open <目录>`      | `dev.duxlabs.files.desktop`                |
| 浏览器“显示所在文件夹” | Dux 的 `org.freedesktop.FileManager1` 服务 |
| 新窗口                 | app-id `dev.duxlabs.files`，进入 `9file`   |
| 打开终端               | 自动识别已安装的 kitty                     |

配置入口：`flake.nix` 的 `dux-files` input 固定 `v2.1.2`，依赖跟随主 `nixpkgs`；
`modules/nixos/desktop/file-manager.nix` 导入官方 NixOS 模块，安装 Dux 与 Quickshell，启用图形会话的
`dfiles.service` 并强制原生 Wayland。服务 PATH 包含系统和用户应用，避免“打开终端”和 Open
With 在后台启动时找不到程序。目录 MIME 默认关联在
`home/linux/gui/base/xdg/mime.nix`，快捷键和窗口规则仍在本专题列出的 KDL 文件。

Dux 独立运行，不需要安装 Dux Shell；外观在应用 Settings 中调整，配置保存在
`~/.config/dfiles/ui-settings.json`。当前未由 Nix 接管该文件，应用内修改可持久保存。打开、保存文件对话框继续使用现有 GNOME/GTK
portal；`programs.dux-files.portal.enable` 保持默认关闭。`Mod+E` 仍是 Noctalia 会话菜单。

apollo 已构建并切换到包含 Dux 的系统代，Home
Manager 激活成功；Dolphin、Thunar、Ark 及 Thunar 插件从当前系统命令与应用入口移除。临时用户 profile 安装项、运行时服务覆盖和 GC
root 已清理。`dfiles.service` 使用系统配置，随图形会话启动。

athena、generic 加载同一模块，下次部署时同步生效；部署命令为
`just local`。旧系统代仍可用于回滚，其中的 Nix store 文件由后续常规垃圾回收处理。

常用命令：

```bash
dfiles                         # 显示窗口
dfiles open ~/Downloads        # 打开目录
dfiles open --new-window ~     # 新窗口
dfiles select ~/Downloads/a.pdf
dfiles ipc system.fileManager.get
systemctl --user status dfiles
```

验证覆盖：`niri validate`、`just test`、三台 Linux 桌面迁移选项和 apollo
toplevel 求值；实际构建并启动 Dux `2.1.2`，检查窗口 app-id、`9file` 落点、`xdg-open`
和 FileManager1 文件定位；临时目录内的中文带空格路径完成复制、改名、移动、撤销和文本预览，复制前后字节相同。未验证中文输入法候选框或远程共享登录；启动日志有 Quickshell
pragma 与 Qt portal 注册警告，已观察到的文件操作和窗口显示正常。

回滚：把
`inode/directory`、窗口规则、快捷键和图形包列表一起改回选定的文件管理器，移除 Dux 模块与 input，再执行
`just local`；保留用户文档和 Dux 配置数据。也可回滚到之前的 NixOS
generation，随后重新登录，让图形会话使用该代的文件管理器服务与目录关联。

参考：[官方 NixOS 模块](https://duxlabs.dev/docs/dfiles/nixos-flake)、
[v2.1.2 发布](https://github.com/duxlabs-dev/dux-files/releases/tag/v2.1.2)。

## 快捷键

使用 `Alt + Space` 打开或关闭 Noctalia 应用启动器。`Mod + D` 和 `XF86Search`
保留为备用入口。由于该键位由 Niri 全局处理，应用自身的 `Alt + Space`
快捷键不会收到按键；如需恢复原配置，将 `keybindings.kdl` 中的 `Alt+Space` 改回 `Mod+Space`。

当前使用 `Mod + 数字` 切换工作区:

```text
Mod + 1    1terminal
Mod + 2    2browser
Mod + 3    3docs
Mod + 4    4codex
Mod + 5    5code
Mod + 6    6chat
Mod + 7    7misc
Mod + 8    8music
Mod + 9    9file
Mod + 0    0other
```

使用 `Mod + Ctrl + 数字` 把当前 column 移动到对应工作区。

使用 `Mod + Shift + 0` 重新整理当前 Niri 运行时工作区顺序:

```text
1terminal, 2browser, 3docs, 4codex, 5code, 6chat, 7misc, 8music, 9file, 0other
```

脚本从大 index 往小依次调用 `move-workspace-to-index --reference`（先 `0other:10`，再
`9file:9`、`8music:8`……），倒序才能收敛到目标布局；只调整顺序，不关闭窗口。

## Bar 显示

Niri 会在每个显示器末尾保留一个无名空工作区。Noctalia v5 的
`[widget.workspaces] hide_when_empty=true` 与 `labels_only_when_occupied=true`
隐藏无窗口且非当前的空胶囊；切到空命名工作区仍显示数字，离开后隐藏。`Win+N` 跳转和窗口规则保持。

数字胶囊采用主色聚焦、占用低强调、独立 urgent 红点和 hover 描边；编号 `10` 完整显示，
`focused_output_only=true` 区分全局焦点与另一屏 active。配置入口是
`home/linux/gui/base/noctalia/config/config.toml`，呈现由 `overlays/noctalia/workspace-states.patch`
补齐，详见 [工作区状态](./noctalia-workspace-urgent.md)。

活动 out-of-store Niri KDL 已迁为 `noctalia msg` 并通过
`niri validate`，apollo 已完成原生 v5 修正版的 `switch`。双窗 urgent、空命名工作区、数字
`10`、点击和滚轮已实际验收；真实错误/正确密码解锁已通过，物理全局快捷键未验收。切换与完整回滚见
[Noctalia v5](./noctalia-v5.md)。

## app-id 校准

新增应用规则前，先在 Niri 会话里打开应用，然后查看实际 app-id 和 title:

```bash
niri msg windows
```

优先用稳定的 `app-id` 匹配；Electron、AppImage 或沙箱应用 app-id 不稳定时，再补 title 规则。

微信在本机使用以下窗口标识；新版原生 Wayland 保留相同 app-id:

```text
App ID: "wechat"
Title: "Weixin"
```

因此 `windowrules.kdl` 同时匹配 `wechat`、`com.tencent.WeChat`、`WeChat`、`Weixin` 和 `微信`。

腾讯会议实测使用：

```text
App ID: "wemeetapp"
Title: "腾讯会议"
```

规则使用 `wemeetapp`，让主窗口和辅助窗口统一进入 `0other`。

## 验证

静态验证:

```bash
niri validate
```

运行时验证:

```bash
niri msg action load-config-file
niri msg -j workspaces
niri msg windows
niri msg workspaces
```

期望聊天应用进入 `6chat`，代码编辑器进入 `5code`，音乐进入
`8music`，Clash、Zoom 和腾讯会议等工具进入 `0other`。

如果某个窗口已经在旧工作区，重新加载配置不会自动迁移它；窗口规则主要影响新创建的窗口。可以手动移动当前窗口:

```bash
niri msg action move-window-to-workspace 6chat
```
