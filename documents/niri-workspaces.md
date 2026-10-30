# Niri 工作区与窗口分配

本文记录 NixOS 桌面在 Niri 下的工作区命名、快捷键和窗口自动分配规则。

## 当前工作区语义

| 工作区      | 语义       | 自动进入的应用                                                  |
| ----------- | ---------- | --------------------------------------------------------------- |
| `1terminal` | 终端       | `foot`、`footclient`（server 模式窗口）、`Alacritty`、`Ghostty` |
| `2browser`  | 浏览器     | `Zen`、`Chrome`                                                 |
| `3docs`     | 文档笔记   | `Obsidian`、`Apostrophe`、Notion、Linear                        |
| `4codex`    | Codex GUI  | `ChatGPT`、`Codex`、`Claude` 等 AI 图形客户端                   |
| `5code`     | 代码编辑器 | `VSCode`、`Cursor`、`Zed`                                       |
| `6chat`     | 聊天沟通   | `Slack`、`Telegram`、飞书、微信、QQ                             |
| `7misc`     | 空白暂存   | 无固定分配，临时窗口随手放                                      |
| `8music`    | 音乐       | QQ 音乐、网易云音乐                                             |
| `9file`     | 文件/阅读  | `Foliate`、`Dolphin`、`Sioyek`                                  |
| `0other`    | 其他工具   | `FlClash`、`Zoom`、腾讯会议                                     |

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

Niri 会在每个显示器末尾保留一个无名空工作区（`niri msg workspaces` 里的 index
11），数字键管不到，也无法关闭；Noctalia
bar 默认把它和空着的命名工作区一起画成无号胶囊。当前通过 Noctalia 的
`bar.widgets.center[0].hideUnoccupied = true` （settings.json，v4
schema）隐藏所有"无窗口且非当前"的工作区胶囊：`Win+N`
跳转和窗口规则不受影响，跳到某个空工作区时它作为当前工作区仍会显示，离开后空着就隐藏。

## app-id 校准

新增应用规则前，先在 Niri 会话里打开应用，然后查看实际 app-id 和 title:

```bash
niri msg windows
```

优先用稳定的 `app-id` 匹配；Electron、AppImage 或沙箱应用 app-id 不稳定时，再补 title 规则。

当前已确认微信 AppImage 在本机可能显示:

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
