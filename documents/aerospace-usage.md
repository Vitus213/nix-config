# AeroSpace 使用指南

这份文档说明的是当前仓库里这套 AeroSpace 配置应该怎么用，而不是 AeroSpace 的通用默认配置。

当前配置源文件:

- `home/darwin/aerospace/aerospace.toml`

当前部署方式:

- `~/.aerospace.toml` 由 Home Manager 管理
- 这个路径最终解析回仓库里的 `home/darwin/aerospace/aerospace.toml`
- 也就是说，改仓库里的这个文件，实际就是在改 AeroSpace 正在读取的配置文件
- 只改键位、窗口规则、工作区规则时，通常执行一次 `aerospace reload-config` 就够了，不需要每次都重新
  `home-manager switch`

## 1. 先理解这套配置的心智模型

这套配置可以先记住 5 个原则:

1. `Option` 键就是主修饰键，也就是配置文件里的 `alt`
2. `h/j/k/l` 负责方向操作，和 Vim 一样
3. 数字键负责切工作区，`Shift + 数字键` 负责把窗口送去对应工作区
4. 你现在主要在两个模式里工作: `main` 和 `service`
5. 不是所有窗口都会自动平铺，很多窗口会按规则被送去指定工作区，没命中规则的窗口默认浮动

额外还有两个和体验直接相关的行为:

- 当焦点切到另一块显示器时，鼠标会自动移动到那块显示器的中间附近
- AeroSpace 尝试在启动时调用 `borders`
  给焦点窗口画彩色边框；如果本机没有这个命令，通常只是没有彩色边框，不影响核心窗口管理

## 2. 启动、确认它是否在工作

当前配置启用了开机自启，所以正常情况下登录 macOS 后 AeroSpace 会自动启动。

如果你怀疑它没有起来，可以手动启动:

```bash
open -a AeroSpace
```

第一次使用时要确认两个系统条件:

1. AeroSpace 已安装
2. 在 macOS 的 `Privacy & Security > Accessibility` 里给了 AeroSpace 辅助功能权限

可以用下面这些命令确认它在运行:

```bash
aerospace list-apps
aerospace list-workspaces
aerospace list-monitors
```

如果这些命令能正常返回内容，说明 AeroSpace 服务已经起来了。

## 3. 主模式 `main` 的日常快捷键

你平时绝大多数时间都在 `main` 模式。

### 3.1 打开应用

```text
Option + Enter
```

作用:

- 打开 `Ghostty`

注意:

- 这个快捷键打开的是 `Ghostty`
- `Ghostty` 会自动进入 `1Term`
- 而且会以平铺窗口的方式加入当前工作流

### 3.2 切换焦点

```text
Option + h    向左切焦点
Option + j    向下切焦点
Option + k    向上切焦点
Option + l    向右切焦点
```

这是最常用的一组键。哪个窗口获得焦点，后续的移动、缩放、切布局，都是对它操作。

### 3.3 移动窗口

```text
Option + Shift + h    把当前窗口往左移动
Option + Shift + j    把当前窗口往下移动
Option + Shift + k    把当前窗口往上移动
Option + Shift + l    把当前窗口往右移动
```

这组键不是切换焦点，而是移动当前窗口在布局树中的位置。

### 3.4 改变布局类型

```text
Option + /    切到 tiles 布局
Option + ,    切到 accordion 布局
```

可以先把它理解成:

- `tiles`: 常规平铺
- `accordion`: 手风琴式布局，适合把多个窗口塞进同一个工作区里快速浏览

### 3.5 调整窗口大小

```text
Option + Shift + -    缩小当前窗口
Option + Shift + =    放大当前窗口
```

这是当前配置里实际可直接使用的缩放方式。

### 3.6 切工作区

```text
Option + 1    切到 1Term
Option + 2    切到 2Alacritty
Option + 3    切到 3Work
Option + 4    切到 4Firefox
Option + 5    切到 5Chrome
Option + 6    切到 6Chat
Option + 7    切到 7Work
Option + 8    切到 8Music
Option + 9    切到 9File
Option + 0    切到 0Other
Option + a    切到 A
Option + b    切到 B
```

其中 `A` 和 `B` 更像是两个备用工作区，没有配置自动分配规则，也没有绑定显示器。

### 3.7 把窗口送去别的工作区

```text
Option + Shift + 1    把当前窗口送到 1Term
Option + Shift + 2    把当前窗口送到 2Alacritty
Option + Shift + 3    把当前窗口送到 3Work
Option + Shift + 4    把当前窗口送到 4Firefox
Option + Shift + 5    把当前窗口送到 5Chrome
Option + Shift + 6    把当前窗口送到 6Chat
Option + Shift + 7    把当前窗口送到 7Work
Option + Shift + 8    把当前窗口送到 8Music
Option + Shift + 9    把当前窗口送到 9File
Option + Shift + 0    把当前窗口送到 0Other
Option + Shift + a    把当前窗口送到 A
Option + Shift + b    把当前窗口送到 B
```

这组键在两个场景特别常用:

- 自动分配没命中时，手动把窗口送去你想要的工作区
- 某个窗口临时想跨上下文使用时，快速归类

### 3.8 最近两个工作区来回切

```text
Option + Tab
```

作用:

- 在当前工作区和上一个工作区之间来回跳

这是高频键，尤其适合在浏览器和聊天/终端之间反复切。

### 3.9 把当前工作区移到下一块显示器

```text
Option + Shift + Tab
```

作用:

- 把当前整个工作区移到下一块显示器
- 开启多显示器时尤其有用

## 4. `service` 模式怎么用

你通过下面这个快捷键进入 `service` 模式:

```text
Option + Shift + ;
```

进入以后，接下来按的键不再是普通输入，而是执行一组“维护布局”的操作。

### 4.1 退出或重载配置

```text
Esc
```

作用:

- 重新加载 AeroSpace 配置
- 然后退出 `service` 模式，回到 `main`

如果你刚改完配置文件，这是最直接的重载方式之一。

### 4.2 重整当前工作区布局

```text
r
```

作用:

- 对当前工作区执行 `flatten-workspace-tree`
- 你可以把它理解成“把布局树拍平、重新理顺”

什么时候用:

- 你觉得某个工作区层级套得太深
- 反复 move/join 之后结构开始不好理解

### 4.3 在浮动和平铺之间切换

```text
f
```

作用:

- 把当前窗口在 `floating` 和 `tiling` 之间切换

什么时候用:

- 某个窗口平铺着不好用，想临时拉出来浮动
- 某个浮动窗口想重新纳入平铺布局

### 4.4 关闭当前工作区里除了当前窗口以外的所有窗口

```text
Backspace
```

作用:

- 关闭当前工作区除了当前窗口外的所有窗口

这个操作很强，适合“临时收口”，也适合把一个已经很乱的 workspace 快速清理成只留一个主窗口。

### 4.5 把当前窗口和邻居编组

```text
Option + Shift + h    和左侧邻居编组
Option + Shift + j    和下方邻居编组
Option + Shift + k    和上方邻居编组
Option + Shift + l    和右侧邻居编组
```

作用:

- 对当前窗口执行 `join-with`
- 把当前窗口和对应方向最近的节点放进一个共同父容器里

什么时候用:

- 你想手动做出更细的布局结构
- 你想把两个窗口绑定成一个局部子布局

### 4.6 音量控制

```text
方向键下       降低音量
方向键上       提高音量
Shift + 方向键下    静音
```

这组键只有在 `service` 模式里有效。

## 5. 当前配置的工作区设计

下面这张表是你这套配置的核心。

| 工作区     | 语义           | 自动进入的应用                                  | 显示器绑定 |
| ---------- | -------------- | ----------------------------------------------- | ---------- |
| `1Term`    | 终端区         | `Ghostty`、`Kitty`、`Alacritty`                 | `U32V5N`   |
| `2Firefox` | Firefox 浏览   | `Firefox`                                       | `U32V5N`   |
| `3Docs`    | 文档笔记       | `Notion`、`Typora`、`Obsidian`                  | `U32V5N`   |
| `4Chat`    | 聊天沟通       | `Telegram`、`微信`、`Lark`、`QQ`                | `Built-in` |
| `5Work`    | 工作/开发      | `企业微信`、`Slack`、`VSCode`、`Cursor`         | `U32V5N`   |
| `6Chrome`  | Chrome 浏览    | `Chrome`                                        | `U32V5N`   |
| `7Mail`    | 邮件日历       | `Mail`、`Calendar`                              | `U32V5N`   |
| `8Music`   | 音乐           | QQ 音乐、网易云音乐                             | `Built-in` |
| `9File`    | 文件/阅读/编辑 | `Finder`、`Books`、`Joplin`、`Preview`          | `Built-in` |
| `0Other`   | 其他工具       | `Wireshark`、`LM Studio`、`Clash Verge`、`Zoom` | `Built-in` |
| `A`        | 备用           | 无                                              | `U32V5N`   |
| `B`        | 备用           | 无                                              | `U32V5N`   |

这里有几个重要细节:

- `9File` 里的很多应用被显式配置成浮动窗口
- `VSCode` 和 `Cursor` 现在会去 `7Work`，并以平铺方式打开
- `0Other` 里的 `Wireshark` 和 `LM Studio` 也被显式配置成浮动
- `Clash Verge` 会去 `0Other`，但没有强制浮动
- `SecurityAgent` 和 `System Settings` 被设置成浮动，但不强制移动工作区

## 6. 未命中规则的窗口会怎样

这是这套配置里最容易忽略的一点。

配置文件结尾有一条兜底规则:

- 所有没有被前面规则匹配到的窗口
- 默认都会执行 `layout floating`

所以这套配置并不是“所有新窗口默认平铺”，而是:

- 命中规则的窗口: 按规则决定去哪个工作区，是否浮动
- 没命中规则的窗口: 默认浮动

这意味着如果你装了一个新应用，它第一次出现时大概率会是浮动窗口。想把它纳入固定工作流，ƒ通常有两种做法:

1. 临时使用时，直接手动用 `Option + Shift + 数字` 送到某个工作区
2. 长期使用时，后续给它加一条 `on-window-detected` 规则

## 7. 现在的显示器策略

当前配置按双显示器设计：

- 外接显示器 `U32V5N` 为主力屏，放置主要工作区
- 内置 `Built-in Retina Display` 为辅助屏，放置聊天、音乐、文件和其他工具

如果只接一块显示器，AeroSpace 会自动把所有工作区集中到当前可用的显示器上。

## 8. 推荐的日常使用姿势

### 8.1 终端 + 浏览器 + 聊天

一个很自然的工作流是:

1. `Option + Enter` 打开 `Ghostty`
2. 它会自动进入 `1Term`
3. `Option + 4` 去 Firefox，或者 `Option + 5` 去 Chrome
4. `Option + 6` 去聊天
5. 在两个最近工作区间来回跳用 `Option + Tab`

### 8.2 某个应用自动分配不符合预期

比如你打开了一个应用，它没有进你期望的工作区:

1. 先直接用 `Option + Shift + 数字` 手动送过去
2. 后面如果想把它固定下来，用 `aerospace list-apps` 查它的 app id
3. 再给配置文件补一条 `on-window-detected`

### 8.3 某个窗口现在平铺得不好用

比如系统设置、图片预览、临时对话框之类:

1. `Option + Shift + ;` 进入 `service`
2. 按 `f`
3. 窗口就会在浮动和平铺之间切换

### 8.4 工作区越来越乱

可以这样收拾:

1. `Option + Shift + ;` 进入 `service`
2. 按 `r` 重整布局
3. 如果只想保留当前窗口，按 `Backspace`

### 8.5 多屏调整

如果你之后重新接回多块显示器，并且当前工作区应该去另一块屏幕:

```text
Option + Shift + Tab
```

这会把当前整个工作区移动到下一块显示器。

## 9. 当前配置里的几个“非直觉点”

### 9.1 `Ghostty` 现在就是默认终端工作区

当前配置里:

- 启动快捷键打开的是 `Ghostty`
- `Ghostty` 和 `Kitty` 都会自动进入 `1Term`
- `Ghostty` 还会显式使用平铺布局

所以现在按 `Option + Enter`，终端会直接进入终端工作区并参与平铺。

### 9.2 `resize` 模式虽然定义了，但没有入口快捷键

配置里有一个 `resize` 模式，里面是:

- `h/l` 调整宽度
- `j/k` 调整高度
- `Enter` 或 `Esc` 返回 `main`

但当前 `main` 模式没有任何键进入这个模式，所以平时你实际上用不到它。

如果你临时想试，可以从命令行手动进入:

```bash
aerospace mode resize
```

然后再按 `h/j/k/l` 调大小。

### 9.3 未启用“自动取消隐藏”

配置里把:

```text
automatically-unhide-macos-hidden-apps = false
```

也就是说，如果你用 macOS 的隐藏动作把应用藏起来了，AeroSpace 不会自动帮你把它重新显示出来。

### 9.4 `Esc` 在 `service` 模式里不是单纯退出

它会先执行:

```text
reload-config
```

再回到 `main`。这一点很好用，但也意味着你每次在 `service` 模式里按
`Esc`，本质上都在触发一次配置重载。

## 10. 常用命令行排错命令

下面这些命令在你想搞清楚“为什么它没按预期工作”时很有用。

### 查看正在运行的 GUI 应用及 app id

```bash
aerospace list-apps
```

这个命令非常重要，因为写自动分配规则时你要靠 `app id`。

例如当前机器上可以看到类似结果:

- `com.mitchellh.ghostty` 对应 `Ghostty`
- `com.apple.finder` 对应 `访达`

### 查看当前有哪些工作区

```bash
aerospace list-workspaces
```

### 查看窗口

```bash
aerospace list-windows
```

### 查看显示器

```bash
aerospace list-monitors
```

### 重载配置

```bash
aerospace reload-config
```

如果你刚改了 `aerospace.toml`，这是最直接的验证动作。

## 11. 最后给你的使用建议

如果你想尽快把这套配置用顺，建议先只记住下面这些键:

- `Option + h/j/k/l`: 切焦点
- `Option + Shift + h/j/k/l`: 移窗口
- `Option + 1..0`: 切工作区
- `Option + Shift + 1..0`: 送窗口去工作区
- `Option + Tab`: 在最近两个工作区切换
- `Option + Shift + ;` 然后按 `f`: 临时切浮动
- `Option + Shift + ;` 然后按 `r`: 重整布局

等你把这些动作用熟以后，再去利用自动分配规则，效率会提升得比较明显。
