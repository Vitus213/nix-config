# Noctalia 工作区状态与 urgent 红点

## 当前声明配置：原生 Noctalia 5.5.0（2026-11-13）

仓库已迁移到固定 Noctalia 5.5.0，工作区补丁为 `overlays/noctalia/workspace-states.patch`，配置在
`home/linux/gui/base/noctalia/config/config.toml`。apollo 已完成下文的 DP-1 桌面验收、挂载顺序修正版激活和真实密码解锁检查，并对同一修正版完成
`switch`。

2026-11-15 声明 input 更新到
`6bcea5968d17b7750e27f19f1827dce1a31bbc98`（仍为 5.5.0），用于采用正式 PAM helper。两个固定提交之间
`workspaces_widget.{cpp,h}`
未变，工作区补丁原样保留；通知桥接与本页已记录的样式和红点语义不变。此次未切换或重启桌面，下列运行验收仍属于 11 月 13 日。

补丁仅改变 `WorkspacesStyle::Regular` 的状态呈现：

| 状态                           | 呈现                                                                 |
| ------------------------------ | -------------------------------------------------------------------- |
| 当前聚焦工作区（包括空工作区） | `primary` 主色实心胶囊                                               |
| 非聚焦、有窗口                 | `surface_container_high` 低强调底色                                  |
| 非聚焦、空工作区               | `surface_container`；按 `hide_when_empty=true` 隐藏                  |
| urgent                         | 独立的 Error 色红点，与聚焦、占用和 hover 同时存在，不改底色或文字   |
| hover                          | 保持底色和文字，增加 1 logical px 的 `OutlineVariant` 描边；移出清除 |

红点直径 4 logical px、圆角 2，位于胶囊右上角，内缩 2
px；创建节点只发生在重建阶段，动画每帧不创建节点。可见性读取真实的
`item.workspace.urgent`，而非动画保留的
`visualWorkspace`，因此设置和清除 urgent 不应等待底色动画结束。布局和视觉更新都同步红点；胶囊宽度动画期间也更新其位置。

横向普通胶囊的 active/inactive 宽度均额外增加总计 6
px 的横向留白，文字仍居中；红点不参与布局，urgent 切换不会改变宽度。竖向 Regular 模式在对应尺寸方向增加 6
px。补丁保留上游 active 胶囊动画、点击与滚动行为，其他工作区样式沿用上游呈现。

`focused_output_only=true`
区分全局焦点与其他输出上的 active：只有聚焦输出的当前工作区使用主色，另一输出的 active 使用占用色。数字标签使用工作区 id、最多两字符，确保
`10` 可完整显示；空命名工作区在进入时显示、离开后隐藏。

## 收到通知自动留红点（2026-11-13）

`noctalia-notification-alerts.service`
已在 Apollo 启用。后台工作区收到对应应用的桌面通知后留红点，弹窗超时不清除；进入对应工作区后由 Noctalia 自动清除。正在查看的工作区跳过，不在离开后补点。原有通知弹窗、按钮、历史继续由 Noctalia 提供。

配置入口为 `home/linux/gui/base/noctalia/notification-alerts.nix` 和同目录
`notification-alerts.py`，由 `default.nix` 导入。服务旁路监听 `busctl --user --json=short monitor`
的结构化 `Notify` 调用，以 `desktop-entry`、app-name匹配规则，忽略大小写和末尾
`.desktop`；`desktop-entry`
命中规则时优先。没有新通知时阻塞等待，不轮询历史，不记录通知正文，不查询应用内部的未读数据。

| 通知来源                                        | 提醒工作区                                                         |
| ----------------------------------------------- | ------------------------------------------------------------------ |
| OMP、Herdr                                      | `1terminal`                                                        |
| Slack、微信 / Weixin、Telegram、飞书 / Lark、QQ | `6chat`                                                            |
| 其他应用                                        | 按来源名与 Niri 窗口 app-id 匹配，提醒所有匹配窗口所在的后台工作区 |

前两项沿用现有工作区分工，固定目标不跟随窗口迁移；多个 OMP/Herdr 终端仍只提醒
`1terminal`。其他应用没有匹配窗口时不添加红点。红点表示“收到过新通知”，不表示消息条数或已读状态；应用静音、暂停通知或未发出桌面通知的消息不会触发。勿扰模式只影响 Noctalia 的弹窗策略，桥接仍会收到应用发出的 D-Bus 通知并按规则留点。Noctalia 重启会清空内存中的 alert，服务不回放旧通知。

服务使用 `After` / `PartOf` / `WantedBy=noctalia.service`
跟随桌面，异常退出后 3 秒重启。本机已构建并链接 Nix 生成的同一个用户单元，设置为 enabled，立即生效；未运行整机
`switch`。当前用 `~/.local/state/noctalia-notification-alerts-unit` 保留该单元的 GC
root，后续系统部署由 Home Manager 接管服务文件及启动链接。

实机验收使用本地测试通知，未向 Slack/微信联系人发送消息：

- Slack app-name + desktop-entry：后台 `6chat` 出点，实际截图可见；活动通知列表为空后红点仍在。
- 进入 `6chat`：alert 状态清空，实际截图确认红点消失。
- 实际执行 `herdr notification show`：后台 `1terminal` 出点；OMP app-name 测试通知同样出点。
- 当前 `1terminal` 收到 OMP 测试通知：保持无点，切走后仍无残留。
- 桥接服务重启后，Weixin / `com.tencent.WeChat` 通知及同 id 替换通知仍只保留 `6chat` 一个 alert。
- Nix 包和用户单元构建、`just test`、Nix 格式检查通过；未把受控通知验收当成真实聊天收信验收。

诊断与停用：

```bash
systemctl --user status noctalia-notification-alerts.service
journalctl --user -u noctalia-notification-alerts.service -b
noctalia msg workspace-alert-status
systemctl --user disable --now noctalia-notification-alerts.service
```

停用不会清除已经添加的 alert，进入对应工作区或执行 `noctalia msg workspace-alert-clear 6chat`
即可清除。永久撤销时移除 `default.nix` 中的桥接模块导入后部署；只删除此次单元的手工 GC root
`~/.local/state/noctalia-notification-alerts-unit`，不删除 Nix
store 内容。停用与清除 alert 不影响应用消息和通知历史。

## 桌面验收记录（2026-11-13）

在 DP-1 上创建两个专用 kitty 窗口 `NoctaliaUrgentA`、`NoctaliaUrgentB`，用 Niri
IPC 设置单窗 urgent，并核对窗口状态、工作区状态与实际截图：

1. A/B 同时 urgent：非当前工作区保留占用底色并显示独立红点。
2. 聚焦 A：A 清除，B 仍 urgent；当前工作区为主色，红点仍显示。
3. 聚焦 B：两窗均 clear，红点消失；切走后未重现。
4. hover 描边、点击、进入空命名工作区、离开后隐藏和数字 `10` 完整显示均已检查；真实指针滚轮从
   `2browser` 切到 `3docs`。

本轮专用测试窗口已不再存在。overview 中的状态切换、动画期间的快速设置/清除及多屏焦点区分未实测，不能计为通过。完整切换与恢复顺序见
[Noctalia v5 迁移](./noctalia-v5.md)；回滚必须连同旧包、配置、服务和 Niri 快捷键一起恢复。

## 接入前调查：Slack 未读消息为什么不触发提醒（2026-11-13）

本节记录桥接启用前的调查与临时显示验证；当前自动提醒见上文。调查时实际运行 Noctalia
5.5.0（`c257324`）、Niri 26.04、Slack 4.51.180；Slack 日志中的运行时为 Electron 43.1.1 / Chromium
150.0.7871.114，进程使用原生 Wayland。

### 现场证据

同一次采样中，Slack 的 `storage/root-state.json` 未读快照为
`showBullet=true, unreadHighlights=1, unreads=1`；这些是客户端内部字段，不把数值解释为准确的消息条数。Slack 窗口位于
`6chat`，窗口及工作区的 `is_urgent` 均为 `false`； `noctalia msg workspace-alert-status` 返回
`(no workspace alerts)`，Noctalia 勿扰状态为 `off`。Slack 当天日志另有多次
`Creating new Electron notification`，可确认它曾创建桌面通知；历史通知记录不能还原当时每一刻的窗口紧急状态。

当时没有红点的直接原因是工作区既没有 compositor urgency，也没有 Noctalia
alert。原配置不从 Slack 未读计数或桌面通知自动推导工作区状态；仅修改 `urgent_color`
不会补上这条触发链路。当前服务已连接桌面通知与 workspace alert。

### 三种状态互相独立

- **Slack 未读与徽标**：Slack 自己维护。官方 Linux 说明用托盘徽标区分普通未读与需要注意的活动；不是工作区状态。
- **桌面通知**：由 Slack 通知偏好控制。Slack 将应用内 activity/badge 与桌面 push 开关分开，存在未读不保证弹出通知。
- **工作区提醒**：现有红点读取
  `workspace.urgent`，来源可以是 compositor，或者 Noctalia 的 alert 覆盖；上游通知 daemon 没有自动连接，本仓库由上述独立服务连接。

来源：[Slack 通知指南](https://slack.com/help/articles/360025446073-Guide-to-Slack-notifications)、
[Slack 通知配置（Linux / Windows 分页）](https://slack.com/help/articles/201355156-Configure-your-Slack-notifications)、
[Slack 2026 通知模型说明](https://slack.engineering/how-slack-rebuilt-notifications/)。官方“Flash
window when a notification is received →
Always”属于 Windows 分页，不能当作 Linux 可用开关。Freedesktop 通知的 `low/normal/critical`
是通知自身的级别，也不等于 Niri 的窗口 `is_urgent`：
[通知规范](https://specifications.freedesktop.org/notification/latest/urgency-levels.html)。

匹配本机版本的标准 `flashFrame` 路径也存在 Wayland 限制：
[Electron 43.1.1](https://github.com/electron/electron/blob/v43.1.1/shell/browser/native_window_views.cc#L1229-L1242)
将请求交给 Chromium widget，
[Chromium 150 desktop host](https://github.com/chromium/chromium/blob/150.0.7871.114/ui/views/widget/desktop_aura/desktop_window_tree_host_platform.cc#L890-L892)
继续交给 platform window；其
[基类实现为空](https://github.com/chromium/chromium/blob/150.0.7871.114/ui/platform_window/platform_window.cc#L31)，该版本的 WaylandWindow
/ WaylandToplevelWindow 没有覆盖它。
**推断边界**：若 Slack 使用这条标准调用链，就不会由此提交 attention 请求；本次没有跟踪 Slack 是否调用该 API，不能把它认定为唯一根因，也不能据此得出必须切 X11 的结论。

### Noctalia 已有的接口与缺少的连接

固定版本已内置 `workspace-alert-add`、`workspace-alert-add-window`、`workspace-alert-clear`、
`workspace-alert-clear-all`、`workspace-alert-status`，不是本地绘制补丁增加的功能。alert 只在工作区非 active 时覆盖为 urgent；工作区变化时，优先清除当前交互输出上 active 工作区的 alert。它表达的是“这里有过活动，返回查看即可消除”，不追踪 Slack 中是否已经读完或回复。

官方实现中只有 IPC 处理器调用 alert 的
`add`；通知回调只刷新通知界面，没有添加工作区 alert。当前通知过滤器与 `[hooks]`
也没有“收到通知时运行命令”的配置项。来源：[alert 服务](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/compositors/workspace_alert_service.cpp#L19-L85)、
[IPC](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/app/application_ipc.cpp#L430-L492)、
[切换后清除](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/app/application_services.cpp#L930-L945)、
[通知回调](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/app/application.cpp#L114-L137)、
[通知过滤器](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/services/notifications.mdx#L78-L105)、
[hooks](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/automation/hooks.mdx#L14-L31)。

Luau 插件同样没有内置外部通知订阅、通知 metadata 快照或托盘快照；包装外部进程仍需要实际事件来源。因此自动连接需要小范围原生接入，或者额外的 D-Bus 监听器，不能仅填一个现成通知 hook。现有 SNI
`NeedsAttention` 只改变托盘图标；当前源码没有 Unity
LauncherEntry 未读计数接收实现。这些能力也不能证明 Slack 正在发送对应信号。来源：[插件运行时 API](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/plugins/development/runtime-api.mdx)、
[托盘状态读取](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/dbus/tray/tray_service.cpp#L2131-L2156)。

### 临时显示验证与方案取舍

在工作区 1 保持焦点时执行
`noctalia msg workspace-alert-add 6chat`，实际顶栏数字 6 右上角立即出现小红点；此时 Niri 仍报告
`6chat.is_urgent=false`，证明 Noctalia 自己的 alert 可以独立驱动现有样式。随后执行
`noctalia msg workspace-alert-clear 6chat`，红点消失，status 恢复为空。未切换到 Slack、未发送测试消息。本次没有对“返回工作区自动清除”做交互验证，该行为依据上述固定版本源码。

| 目标语义                                  | 方案与边界                                                                                                                        |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| 收到 Slack 桌面通知后提醒，进入工作区消除 | 在通知接收处增加按应用筛选的连接，调用现成 workspace alert；改动最少，但不覆盖被 Slack 静音、暂停或不产生通知的未读               |
| 只要 Slack 仍有未读就持续提醒             | 需要可靠的应用未读信号及独立清除规则；不能直接使用进入工作区即清除的 alert 当作已读状态。本次仅验证了内部快照，未验证稳定对外接口 |
| 把小红点换成整块红底                      | 只改变绘制补丁；仍需上述触发来源，颜色本身不能检测未读                                                                            |

当前采用桌面通知触发的活动提醒，沿用现有红点和进入工作区后清除的规则；不把通知弹窗消失或进入工作区当作消息已处理。

## 社区现成方案核对（2026-11-13）

本轮检索实际项目、作者讨论和脚本，以下是可核实样本，不代表社区使用率。没有安装插件、调用 Slack 私有接口、发送通知或改动桌面配置；可用性判断来自公开实现与本机版本对照。

### Noctalia 插件：urgent-on-notification

[matt-hb/urgent-on-notification](https://github.com/matt-hb/urgent-on-notification)
的用途与本需求直接相近。固定提交
`0ea2ee827666a5bb0431ce6cedb01166b8891d54`，插件版本 1.0.0，最近提交为 2026-05-28，查询时未归档。

- 收到通知后用 `desktopEntry` / `appName` 匹配 Niri 窗口，执行
  `niri msg action set-window-urgent --id …`；同应用多窗口会全部置 urgent。
- 跟踪 Noctalia 通知历史；该应用的所有已跟踪通知从历史中移除时，执行 `unset-window-urgent`。
- 这是通知历史驱动，不读取 Slack 真实未读；Niri 自身聚焦窗口也会清 urgency。
- 它使用 `Main.qml`、Quickshell `NotificationServer` 和旧
  `NotificationService.historyModel`；当前 Noctalia
  5.5.0 使用 Luau，不能直接安装运行，也不能只改 manifest 版本号。

来源：[作者 README](https://github.com/matt-hb/urgent-on-notification/blob/0ea2ee827666a5bb0431ce6cedb01166b8891d54/README.md)、
[实际实现](https://github.com/matt-hb/urgent-on-notification/blob/0ea2ee827666a5bb0431ce6cedb01166b8891d54/Main.qml)、
[旧 manifest](https://github.com/matt-hb/urgent-on-notification/blob/0ea2ee827666a5bb0431ce6cedb01166b8891d54/manifest.json)、
[当前社区插件接口说明](https://github.com/noctalia-dev/community-plugins#what-a-plugin-is-allowed-to-be)。

### Niri / Waybar：niri_window_buttons 的旁路通知监听

[adelmonte/niri_window_buttons](https://github.com/adelmonte/niri_window_buttons)
是仍在维护的 Waybar CFFI 模块；本轮固定
`5a635e75eb5e5939c3237c2b18f85f54234c881d`，版本 0.4.8，发布于 2026-11-13。它用 D-Bus
`BecomeMonitor` 监听 `org.freedesktop.Notifications.Notify`，按发送进程 PID、`desktop-entry`
和可选 app-id 映射寻找窗口，不取代通知 daemon。

收到通知时，它设置的是模块按钮自己的 `notification_urgent` 状态；按钮的 `.urgent` 样式由
`notification_urgent || compositor_urgent`
决定。窗口变为 focused 时清除该模块状态。因此它证明“旁路监听通知并提醒对应窗口”的实现已有实际项目，但不会自动改变 Niri 或 Noctalia 的工作区状态，也不解析 Slack 真实未读，更没有把弹窗关闭等同于消息已读。来源：[版本](https://github.com/adelmonte/niri_window_buttons/releases/tag/v0.4.8)、
[D-Bus 监听](https://github.com/adelmonte/niri_window_buttons/blob/5a635e75eb5e5939c3237c2b18f85f54234c881d/src/notifications.rs#L117-L174)、
[应用匹配](https://github.com/adelmonte/niri_window_buttons/blob/5a635e75eb5e5939c3237c2b18f85f54234c881d/src/lib.rs#L444-L545)、
[状态设置与焦点清除](https://github.com/adelmonte/niri_window_buttons/blob/5a635e75eb5e5939c3237c2b18f85f54234c881d/src/widget.rs#L269-L280)、
[状态合并](https://github.com/adelmonte/niri_window_buttons/blob/5a635e75eb5e5939c3237c2b18f85f54234c881d/src/widget.rs#L333-L350)。

### Mako / Dunst：通知 hook 直接设置窗口 urgent

两份实际配方把“通知到窗口提醒”的连接写在通知 daemon 的事件脚本里：

- [findus/dotfiles](https://github.com/findus/dotfiles/blob/97a3d2a92ef8f4da8465283235ba9e6b7180a99b/roles/mako/files/config#L7-L8)
  配置 `on-notify=exec ~/bin/mako_urgent`；
  [脚本](https://github.com/findus/dotfiles/blob/97a3d2a92ef8f4da8465283235ba9e6b7180a99b/roles/mako/files/bin/mako_urgent)
  将 Telegram / Thunderbird 的通知 app-name 映射到 app_id，再执行
  `swaymsg [app_id=…] urgent enable`。这是 2020 年的真实配置，脚本最后修改于 2020-05-25。它读取
  `makoctl list` 的第一项，多通知并发时可能匹配错事件；不宜照抄这个读取方式。
- [Dunst #1198 作者原文](https://github.com/dunst-project/dunst/issues/1198)
  明确为了“有空时再去处理，让 Waybar 高亮工作区”，对 Dino 使用
  `script=…`、`skip_display=true`，脚本同样执行 Sway `urgent enable`。维护者指出可以直接使用
  `DUNST_DESKTOP_ENTRY`，作者确认解决。这是 2023 年 Dunst 1.9.2 / Sway
  1.8.1 的配方，不是近期 Niri 安装包。

它们均按应用匹配窗口，工作区随窗口位置决定；脚本没有自己的已读清除回调，主要由 compositor 在聚焦窗口时清除 urgent。通知超时不等于 Slack 已读，Slack 根本不发送系统通知的消息也无法被捕获。借鉴到本机时，可把窗口操作落到已验证的
`workspace-alert-add-window`，保留现有 Noctalia 通知 daemon。不能为了 hook 同时启动 Mako / Dunst /
SwayNC：它们会争抢同一 `org.freedesktop.Notifications` 服务名。

### 浏览器 DOM / 标题：unread-slack

[sharl/unread-slack](https://github.com/sharl/unread-slack) 固定提交
`b901a389f66738a58a18ad0ba0ed6f4f74d0066d`，最近提交为 2026-07-12，查询时未归档。其 userscript 用
`MutationObserver` 检查 Slack 页面 `.p-unread_dot`，存在时给标题加 `(*)` 并调用
`navigator.setAppBadge()`，消失时移除前缀并将 badge 设为 0。这能覆盖没有弹出通知的普通未读，但依赖 Slack 私有 DOM，不能保证未显示在侧栏的活动都被覆盖。仓库托盘程序使用
`win32gui` 与 Windows API；不能直接用于当前 Niri
/ 原生 Slack 客户端。来源：[userscript](https://github.com/sharl/unread-slack/blob/b901a389f66738a58a18ad0ba0ed6f4f74d0066d/Slack%20Unread%20Title%20Notifier.user.js)、
[Windows 监视程序](https://github.com/sharl/unread-slack/blob/b901a389f66738a58a18ad0ba0ed6f4f74d0066d/unread-slack.py)。

### 直接取 Slack 计数：SlackNotifier.spoon

[chriszarate/SlackNotifier.spoon](https://github.com/chriszarate/SlackNotifier.spoon)
是实际维护的 macOS / Hammerspoon 项目，固定提交
`712751488902b8f37f68f43831b300ebf57f5a8a`，最近提交为 2026-10-29，查询时未归档。默认每 60 秒请求
`client.counts` 与 `stars.list`，聚合 DM、activity 和收藏频道未读状态。它需要浏览器会话的 `xoxc`
token 和 `xoxd`
cookie，不能直接安装在 Niri，也不是无需维护的通用接口方案。本轮只读公开代码，没有读取或使用用户 token。来源：[配置与平台要求](https://github.com/chriszarate/SlackNotifier.spoon/blob/712751488902b8f37f68f43831b300ebf57f5a8a/readme.md)、
[请求实现](https://github.com/chriszarate/SlackNotifier.spoon/blob/712751488902b8f37f68f43831b300ebf57f5a8a/init.lua#L316-L330)。

### 实际用户踩过的清除问题

[Niri #2279 的 Slack / Mako 用户报告](https://github.com/niri-wm/niri/discussions/2279#discussioncomment-14382138)
说明手动 `set-window-urgent`
有效，但点击 Slack 通知未在 Niri 下产生其预期的 urgency。这与本机需要额外连接提醒信号的判断相符；该讨论描述的是点击通知后的激活行为，不能据此证明所有新消息都不触发 urgent。

Ask Ubuntu 的
[Slack 提醒不消失讨论](https://askubuntu.com/questions/1478528/ubuntu-23-04-slack-notification-problem)
记录了“Slack 内读过，但桌面计数仍在”的情况：一个回复通过清空通知中心消除，另一个回复建议让Dash-to-Dock 的应用计数覆盖通知计数。它说明“通知中心未读”和“应用未读”混用会造成残留；该 GNOME 配方不适用于 Noctalia，不能照搬其 gsettings 命令。

### 对当前桌面的推荐

最适合借鉴的是 **niri_window_buttons 的旁路事件监听 +
urgent-on-notification 的按应用定位窗口**，输出端使用 Noctalia 已有的 workspace
alert。保留当前顶栏、通知 daemon 和数字红点，不为提醒替换成另一套桌面组件。若采用这种连接，应明确提示“收到过符合 Slack 通知规则的新事件，尚未返回查看”；现成 alert 的返回工作区即清除规则不代表 Slack 已读。

本轮没有找到可直接安装于当前 Noctalia
5.5.0、同时满足“Slack 所有真实未读存在时持续提醒，全部读完才清除”的成熟现成插件。已有真实未读项目分别依赖浏览器 DOM 或会话私有计数接口；这与通知事件提醒是另一种维护取舍。

### 当前原生 v5 社区补充

再次检查 official/community
catalog、`urgent`、`notification workspace`、`workspace-alert-add`、`set-window-urgent`
和 Luau 命中，未找到可直接安装的 v5 通用红点桥接；此范围不代表全社区不存在。

原生 Luau **Contact Notification Sounds 1.5.3 / API 43** 已采用 `runStream()` 驱动外部
`dbus-monitor` 获取 `Notify`
事件，证明旁路监听与当前插件架构并不冲突。但它只播放提示音，不解析 Niri 窗口，也不调用 workspace
alert；本机固定 community
input 与该示例提交不同，未安装或验证该插件。可借鉴监听结构，而不是把它安装后当作红点修复。

来源：[固定示例 manifest](https://github.com/noctalia-dev/community-plugins/blob/0d394e250618b8409fee7a79dece9110d85d9062/contact-sounds/plugin.toml)、[工作原理](https://github.com/noctalia-dev/community-plugins/blob/0d394e250618b8409fee7a79dece9110d85d9062/contact-sounds/README.md#how-it-works)、[监听脚本](https://github.com/noctalia-dev/community-plugins/blob/0d394e250618b8409fee7a79dece9110d85d9062/contact-sounds/scripts/monitor.sh)。Noctalia 的
[workspace alert 官方 PR #3134](https://github.com/noctalia-dev/noctalia/pull/3134)
也明确把它定位为外部 IPC 标记、进入工作区清除的接口，没有声明通知自动关联。

## OMP 与通用通知的官方边界（2026-11-13）

以下仅为官方源码与文档核对，固定 Noctalia 5.5.0 `c2573248a89470383e41b8e1ac432424691cbc1f`、Niri
v26.04 `8ed0da44d974c32c6877d2f4630c314da0717ecb`，不增加本机运行验收结论。
**该版 Noctalia 有工作区 alert，但没有 notification → workspace alert 的自动连接或配置开关。**
[通知事件回调](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/app/application.cpp#L114-L137)
只更新通知已见状态和界面；
[过滤器](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/services/notifications.mdx#L78-L105)
控制弹窗、历史、声音、DND 和时长，
[hooks](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/automation/hooks.mdx#L14-L31)
没有 notification-received 事件；`urgent_color` 只是绘制，不是检测开关。

### 两条提醒链路与清除语义

- **Compositor urgent**：Niri 接受客户端的无输入 serial 的 `xdg_activation_v1`
  token，将其视为 urgency-only；客户端必须再对目标 surface 请求 activation，才设置窗口 urgent。有效输入 serial 的路径则用于激活窗口，不应把“点击通知请求聚焦”当成“收到通知设置 urgent”。来源：[Niri activation 处理](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/handlers/mod.rs#L771-L841)。已聚焦窗口拒绝置 urgent；焦点状态变化清除该窗 urgent。工作区是“任意窗口 urgent”的 OR 聚合，聚焦其中一窗不保证其他 urgent 窗口也清除。来源：[窗口规则](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/window/mapped.rs#L390-L397)、
  [置位规则](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/window/mapped.rs#L601-L609)、
  [工作区聚合](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/layout/workspace.rs#L1828-L1830)。Niri 把结果发到
  [ext-workspace](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/protocols/ext_workspace.rs#L260-L272)，Noctalia
  [直接读取 urgent 位](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/compositors/ext_workspace/ext_workspace_backend.cpp#L384-L397)。
  `niri msg action set-window-urgent --id <id>` / `unset-window-urgent --id <id>`
  是官方的显式控制入口，不是自动通知规则：[IPC 定义](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/niri-ipc/src/lib.rs#L923-L933)。
- **Noctalia alert**：`workspace-alert-add <workspace>` 接受现有工作区的 id/name/index；
  `workspace-alert-add-window <window-id>`
  只解析已知窗口当时所在工作区，然后存工作区 token，不持续跟随该窗口移动。多个事件折叠为同一个 token，没有消息数或已读数。alert 只为非 active 工作区覆盖
  `urgent=true`，不写回 Niri；原有 compositor
  urgent 不被覆盖为 false。即使当前工作区 active，add 仍存 token，离开后可显现，返回时清除。来源：[IPC](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/app/application_ipc.cpp#L430-L492)、
  [存储与叠加](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/compositors/workspace_alert_service.cpp#L19-L85)、
  [窗口解析](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/compositors/compositor_platform.cpp#L1477-L1501)。工作区变化时清除交互输出上 active 工作区的 token；无已知交互输出才退回所有输出。
  `workspace-alert-clear` / `clear-all` 只清 shell
  alert，不能清 Niri 的窗口 urgent。来源：[自动清除](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/app/application_services.cpp#L930-L945)、
  [先取 compositor 状态再叠加](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/compositors/compositor_platform.cpp#L1430-L1457)。

### 通知能否可靠定位 OMP 所在窗口

Noctalia 通知对象保存 `appName`、`desktopEntry`、D-Bus `sender`、通知 urgency 等，
**没有目标 window-id/workspace-id**；接收 `Notify`
时也没有把发送方解析为窗口的步骤。因此不能假设通知标题 `omp` 就是 Niri
app-id，或同为终端的多个窗口可由应用名唯一定位。来源：[通知对象](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/notification/notification.h#L50-L78)、
[接收转换](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/dbus/notification/notification_service.cpp#L428-L466)。点击通知时，Noctalia 将
`ActivationToken` 和 `ActionInvoked` 定向发回原 D-Bus
sender，由客户端响应，而不是 shell 按名称猜窗口：
[动作发送](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/dbus/notification/notification_service.cpp#L546-L595)。

Luau 的 `notify` / `notifyError` 是**发送**通知；该版没有接收外部通知的订阅或通知/窗口快照 API。
`runStream` 可以包装外部监听进程，`runAsync`
可以调用现成 IPC，但事件来源和映射策略仍需自定义。来源：[通知 API](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/plugins/development/runtime-api.mdx#L92-L110)、
[外部进程 API](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/plugins/development/runtime-api.mdx#L268-L301)。另有 Noctalia 的 D-Bus
`GetNotifications` 扩展可读活动通知与
`desktop_entry`，但没有窗口 id、sender 或新增通知信号，不是历史/已读快照；轮询它也仍是自定义桥接，且可能漏掉短暂通知。来源：[接口和字段](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/dbus/notification/notification_service.cpp#L117-L143)、
[活动项序列化](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/dbus/notification/notification_service.cpp#L473-L489)。

### 当前可用选择与版本边界

- 只要求“忽略弹窗后仍有提醒”：官方已有
  [notifications 顶栏组件](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/bar/widgets/notifications.mdx)，显示通知未读数，不定位工作区。外部通知超时仍留历史，打开通知页标记已见；这也不是应用真实已读。来源：[历史语义](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/docs/user/services/notifications.mdx#L62-L64)、
  [已见回调](https://github.com/noctalia-dev/noctalia/blob/c2573248a89470383e41b8e1ac432424691cbc1f/src/app/application.cpp#L124-L129)。
- 要求“对应工作区红点”：应用/终端自行发送 attention，或在产生事件处拿到准确窗口 id 后调用上述 IPC。监听所有 D-Bus 通知并按应用名、desktop-entry、PID 匹配窗口，也只能算**自定义桥接**；必须定义同应用多窗口、无法匹配、当前已聚焦时是否提醒，以及返回工作区还是逐窗聚焦时清除。不应把
  `critical` 通知级别、弹窗超时、通知历史删除、应用未读四者互相替代。
- 旧 v4.7.7 也不是自动联动的证据：固定提交 `3abfa1fc09b62dc4cdeeb7b787886f075696f0b7` 的
  [通知接收器](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Services/System/NotificationService.qml#L138-L173)
  仅过滤、存历史、弹窗和发声；
  [NiriService](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Services/Compositor/NiriService.qml#L108-L125)
  读取 `ws.urgent`。旧通知服务虽有
  [按应用名找窗口并聚焦的辅助函数](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Services/System/NotificationService.qml#L1032-L1051)，但不等于收到通知就置 urgent；旧 QML 插件不能视作 v5
  Luau 原生可用。

## 本机 OMP、Herdr 与终端对照（2026-11-13）

本次 Apollo 实际运行 Noctalia 5.5.0（`c257324`）、Niri 26.04、OMP 18.13.1、Herdr
0.9.5。声明式默认终端已是 kitty 0.49.2，但用户当前窗口仍为存活的 foot 1.28.0（app-id
`foot`），内部存在有效 Herdr pane 标记；不能把声明式切换当作旧进程已退出。

OMP 的完成事件调用 `TERMINAL.sendNotification`，本机在 Herdr 中优先执行
`herdr notification show`。该路径成功启动后直接返回，不再发送 BEL 或 OSC 99。Herdr 当前
`[ui.toast] delivery="system"`，Linux 实现用 `notify-send --app-name Herdr`
弹出系统通知，没有设置 Niri
urgent 或携带目标窗口 id。由此可见，改变 kitty 的 bell 设置不会连接当前 Herdr 的系统通知。

来源：[OMP 完成事件](https://github.com/can1357/oh-my-pi/blob/v18.13.1/packages/coding-agent/src/modes/controllers/event-controller.ts#L3093-L3115)、[Herdr 优先路由](https://github.com/can1357/oh-my-pi/blob/v18.13.1/packages/tui/src/multiplexers/herdr.ts#L35-L50)、[终端发送分支](https://github.com/can1357/oh-my-pi/blob/v18.13.1/packages/tui/src/terminal-capabilities.ts#L176-L197)、[Herdr 0.9.5 通知配置](https://github.com/herdrdev/herdr/blob/v0.9.5/docs/next/website/src/content/docs/configuration.mdx#notifications)、[Linux 系统通知](https://github.com/herdrdev/herdr/blob/v0.9.5/src/platform/linux.rs#L975-L999)。

受控验证在新建的独立 kitty 窗口中进行，窗口移到非当前
`3docs`，测试后退出窗口并恢复原焦点；未修改永久配置、发送聊天消息或重启桌面：

| 输入事件                                                             | Niri 窗口 / 工作区 urgent | Noctalia 结果                                  |
| -------------------------------------------------------------------- | ------------------------- | ---------------------------------------------- |
| 与 OMP 相同的 OSC 99，`app=omp`、`type=completion`、点击动作为 focus | 均为 false                | D-Bus 确认通知到达；无工作区 alert             |
| `notify-send`，app-name 与 desktop-entry 均匹配测试窗口              | 均为 false                | 普通通知不会自动连接红点                       |
| 同一后台窗口发送 BEL，`window_alert_on_bell=yes`                     | 均为 true                 | 顶栏对应工作区显示红点；聚焦测试窗口后清除     |
| `noctalia msg workspace-alert-add-window <测试窗口 id>`              | Niri 仍为 false           | Shell alert 独立显示红点；返回该工作区自动清除 |

OSC 99 的 D-Bus 消息实际为 `app_name="omp"`、`category="completion"`、notification
urgency=1，没有 window-id /
desktop-entry；它的点击 focus 动作不等于收到时请求注意。kitty 官方把桌面通知与 BEL 分为两套接口：`window_alert_on_bell`
默认 yes，但只控制 bell。可用 `notifications.py`
为终端通知增加自定义动作，不能据此声称 GUI 应用或 Herdr system 通知也会被接管。

来源：[kitty 0.49.2 通知协议](https://github.com/kovidgoyal/kitty/blob/v0.49.2/docs/desktop-notifications.rst)、[bell 选项](https://github.com/kovidgoyal/kitty/blob/v0.49.2/kitty/options/definition.py#L1544-L1552)、[官方通知脚本示例](https://github.com/kovidgoyal/kitty/blob/v0.49.2/docs/notifications.py)、[OSC 99 桌面发送实现](https://github.com/kovidgoyal/kitty/blob/v0.49.2/kitty/notifications.py#L756-L798)。

当前需求为“后台工作区收到新通知后留点，进入该工作区后清除”，沿用原生 workspace
alert。用户明确只需通知红点后，当前服务采用既有工作区分工：`Herdr/OMP → 1terminal`、聊天应用
`→ 6chat`。这项策略不需要解析终端 PID，也不声称能够定位跨工作区的具体终端；实现与验收见上文。

## 历史：v4 QML urgency 同步补丁（2026-10-26）

当时组件为 Niri 26.04、noctalia-shell 4.7.7、noctalia-qs 0.0.12。顶栏曾在 `niri msg -j workspaces`
已报告 `is_urgent: false` 后仍保留红色，聚焦时显示聚焦色，切走后又变红。

旧 noctalia-qs 的 Niri IPC（`src/wayland/niri/ipc/connection.cpp`）没有处理
`WorkspaceUrgencyChanged` / `WindowUrgencyChanged` 增量事件，只在工作区快照或主动刷新时读取
`is_urgent`。旧 QML 组件的颜色优先级为“聚焦 >
urgent > 有窗口 > 空”，因此切走后才暴露残留 urgent 颜色。这是当时版本的诊断，不代表 v5 原生实现。

原 `overlays/noctalia-shell/default.nix` 在 `Services/Compositor/NiriService.qml` 的
`Connections { target: Niri }` 中注入以下刷新逻辑：

```qml
function onRawEvent(event) {
  if (event.type === "WorkspaceUrgencyChanged")
    Niri.refreshWorkspaces();
}
```

旧补丁以 `substituteInPlace --replace-fail`
保护锚点。v5 使用原生 ext-workspace 更新 active/urgent，并由 Niri
IPC 补齐 index/occupancy；此次已移除旧 QML 补丁，不再通过重启 `noctalia-shell`
或刷新 QML 快照处理当前声明配置。

## 社区方案与当前取舍（2026-11-13）

本轮限定检索 GitHub 仓库
`niri notifications`、`niri urgent`、`notification urgency wayland`，以及代码
`workspace-alert-add[-window]`、`set-window-urgent` + `Notify/notification`、`niri` +
`BecomeMonitor/dbus-monitor/Notify urgent`。未找到新的、可直接旁路监听桌面 Notify 并写入当前 Noctalia/Niri
urgency 的完整独立项目；此结论限于上述公开索引范围，不代表全社区不存在。

补充可借鉴的真实配方是
[paholg/dotfiles 的 mark-urgent](https://github.com/paholg/dotfiles/blob/7195eb03b1f12a614d06831ee28435cbe98581fd/home/gui/niri/mark-urgent.nix)：Home
Manager 定义 systemd 用户 socket，接收来源 PID、沿 `/proc` 父进程寻找 Niri 窗口，然后执行
`set-window-urgent`。它不占通知服务名，可保留 Noctalia；但它**不监听 Notify**，调用方须主动提供 PID。[调用脚本](https://github.com/paholg/dotfiles/blob/7195eb03b1f12a614d06831ee28435cbe98581fd/bin/mark-urgent)明确传
`$KITTY_PID`，不是按通知 app-name 匹配；因此多个独立 kitty 进程可用 PID 区分，而同 PID 拥有多个 Niri 窗口时脚本会取到多个 id，不能保证正确调用。源码没有自设清除逻辑，沿用 Niri 聚焦窗口清 urgency；这与“进入工作区即清”的 workspace
alert 不同。该文件最后修改于
[2026-06-10](https://github.com/paholg/dotfiles/commit/46644c158cc91a6998aa056c6ac0c01003d4104d)，查询时仓库没有 GitHub
release；它提供 Nix 内联脚本及用户单元，不能称为已有独立发行包或通用通知桥接。

另一个独立旁路实例
[niri-notify-focus v0.2.2](https://github.com/Oaklight/niri-notify-focus/blob/v0.2.2/README_zh.md#工作原理)已有 systemd 用户服务、[AUR 构建配方](https://github.com/Oaklight/niri-notify-focus/blob/v0.2.2/PKGBUILD)和
[2026-11-10 发布](https://github.com/Oaklight/niri-notify-focus/releases/tag/v0.2.2)，不替代通知 daemon。但它的功能是
**ActionInvoked 后聚焦并改变窗口尺寸产生脉冲**，配置只有 pulse/effect，没有“收到 Notify 时置 urgent”入口；不能把点击定位当成通知红点方案。其
[实现](https://github.com/Oaklight/niri-notify-focus/blob/v0.2.2/niri-notify-focus)还存在同 PID 多窗口只保留一个映射、短命通知进程查询 PID 的竞态，不能据 README 的“精准定位”推定覆盖 Herdr。值得借鉴旁路监听与 PID 溯源，但不值得为本需求 fork 整套点击聚焦/尺寸动画。

Herdr 0.9.5 只执行
[`notify-send --app-name Herdr`](https://github.com/herdrdev/herdr/blob/v0.9.5/src/platform/linux.rs#L975-L1009)，未传终端 app-id、窗口 id 或 desktop-entry，无法仅凭应用名区分多个终端窗口。当前目标是按既有工作区分工留提醒，因此采用显式规则
`Herdr/omp → 1terminal`、聊天应用 `→ 6chat`，直接调用
`workspace-alert-add`，由 Noctalia 绘制和清除；不维护第二套通知历史或已读状态。

固定目标不跟随窗口迁移，也不追溯 Herdr 服务复用前的终端来源。需要精确定位终端时才涉及发送端窗口标识或 PID 映射；当前实现与使用方式见“收到通知自动留红点”。
