# Noctalia 工作区状态与 urgent 红点

## 当前声明配置：原生 Noctalia 5.5.0（2026-11-13）

仓库已迁移到固定 Noctalia 5.5.0，工作区补丁为 `overlays/noctalia/workspace-states.patch`，配置在
`home/linux/gui/base/noctalia/config/config.toml`。apollo 已完成下文的 DP-1 桌面验收、挂载顺序修正版激活和真实密码解锁检查，并对同一修正版完成
`switch`。

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

## Slack 未读消息为什么不触发工作区提醒（2026-11-13 调研）

本节只记录调查与临时显示验证，没有启用自动提醒、修改 Slack 偏好或部署新配置。实际运行版本为 Noctalia
5.5.0（`c257324`）、Niri 26.04、Slack 4.51.180；Slack 日志中的运行时为 Electron 43.1.1 / Chromium
150.0.7871.114，进程使用原生 Wayland。

### 现场证据

同一次采样中，Slack 的 `storage/root-state.json` 未读快照为
`showBullet=true, unreadHighlights=1, unreads=1`；这些是客户端内部字段，不把数值解释为准确的消息条数。Slack 窗口位于
`6chat`，窗口及工作区的 `is_urgent` 均为 `false`； `noctalia msg workspace-alert-status` 返回
`(no workspace alerts)`，Noctalia 勿扰状态为 `off`。Slack 当天日志另有多次
`Creating new Electron notification`，可确认它曾创建桌面通知；历史通知记录不能还原当时每一刻的窗口紧急状态。

因此，当前没有红点的直接原因是工作区既没有 compositor urgency，也没有 Noctalia
alert。当前配置不从 Slack 未读计数或桌面通知自动推导工作区状态。仅修改 `urgent_color`
不会补上这条触发链路。

### 三种状态互相独立

- **Slack 未读与徽标**：Slack 自己维护。官方 Linux 说明用托盘徽标区分普通未读与需要注意的活动；不是工作区状态。
- **桌面通知**：由 Slack 通知偏好控制。Slack 将应用内 activity/badge 与桌面 push 开关分开，存在未读不保证弹出通知。
- **工作区提醒**：现有红点读取
  `workspace.urgent`，来源可以是 compositor，或者 Noctalia 的手动 alert 覆盖；通知 daemon 没有自动将二者连接。

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

建议先采用按 Slack 桌面通知触发的活动提醒，沿用现有红点和返回查看后清除的规则。如果要求“全部处理完才消失”，应先确认读完、回复或手动确认中的哪一种才算处理完，再选择真实状态来源；不把通知弹窗消失或进入工作区当作消息已处理。

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
