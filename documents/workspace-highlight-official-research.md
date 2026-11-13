# Noctalia 4.7.7 工作区高亮：官方源码与 Niri 状态调研

调研日期：2026-11-10。只读调查；未修改桌面配置、补丁或运行状态，未执行构建、测试或格式化。下文分别标识官方源码事实、本机采样与推断，不把 issue 报告等同于已证实的本机根因。

本文保留 2026-11-10 的 v4 调研快照；其中“当前”均指调查当时。v5 声明配置与本轮验证状态见
[Noctalia v5](./noctalia-v5.md)，不能用本文旧 JSON/QML 路径判断新版行为。

## 结论

1. 当前数字胶囊不是“所有非当前工作区都灰色”的两态组件，而是 **hover > focused > urgent > occupied >
   empty** 五级颜色决策。拉长另看 `isActive`，不看
   `isFocused`。这两套状态在多屏时并不等价。[胶囊颜色](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Extras/WorkspacePill.qml#L85-L95)、[文字颜色](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Extras/WorkspacePill.qml#L127-L137)、[active 形状](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Extras/WorkspacePill.qml#L41-L53)
2. 本次采样工作区 2 的红底对应 **Niri 的真实
   `is_urgent=true`**，不是仅凭截图推断的缓存假红。该工作区有四个仍 urgent 的 Zen 窗口。Niri 对工作区 urgency 使用
   `any(window.is_urgent)`，聚焦一个窗口不会批量清空同工作区其余窗口的 urgency。[工作区聚合](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/layout/workspace.rs#L1828-L1830)、[逐窗口清除](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/window/mapped.rs#L390-L398)
3. 仓库已经有针对旧版 Niri
   IPC 丢失 urgency 增量事件的刷新补丁，而且运行中的 QML 已包含它。该补丁负责同步状态，**不负责消除 Niri 的真实 urgency**。不能因当前红底还存在就断言补丁没生效。见下文补丁覆盖范围。
4. 保留目前“不显示应用、只显示数字胶囊”的布局，同时把 urgent 从整块红底改成小点，**4.7.7 现有 Workspace 配置项不能做到，需要修改 QML**。`showBadge=false`
   只隐藏 grouped/app 模式的工作区编号 badge，不影响此处数字胶囊的 urgent 红底。[胶囊属性及硬编码红底](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Extras/WorkspacePill.qml#L9-L28)、[grouped badge](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Widgets/Workspace.qml#L860-L903)

## 1. 版本来源，不把 Quickshell 版本当作 Shell 版本

`flake.lock` 中没有单独的 `noctalia` input。实际依赖链为：

- 本仓库 `home/linux/gui/base/noctalia/default.nix:10` 使用 `pkgs.noctalia-shell`。
- 本仓库 `flake.lock:379-392` 固定 nixpkgs revision：`8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe`。
- 该 nixpkgs 的
  [noctalia-shell package.nix](https://github.com/NixOS/nixpkgs/blob/8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe/pkgs/by-name/no/noctalia-shell/package.nix)
  固定 **Noctalia Shell 4.7.7**，来源 `noctalia-dev/noctalia` 的 `v4.7.7`；该 tag 解引用为 commit
  **`3abfa1fc09b62dc4cdeeb7b787886f075696f0b7`**。下文 Shell 源码链接均固定该 commit，不以新版本 main 代替。
- 该 nixpkgs 的
  [noctalia-qs package.nix](https://github.com/NixOS/nixpkgs/blob/8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe/pkgs/by-name/no/noctalia-qs/package.nix)
  固定 **noctalia-qs 0.0.12**，commit **`e7224b756dcd10eec040df818a4c7a0fda5d6eff`**。
- 该 nixpkgs 的
  [niri package.nix](https://github.com/NixOS/nixpkgs/blob/8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe/pkgs/by-name/ni/niri/package.nix)
  固定 **Niri 26.04**，commit **`8ed0da44d974c32c6877d2f4630c314da0717ecb`**。

本机直接读取
`systemctl --user show noctalia-shell.service -p ExecStart -p MainPID -p FragmentPath`，得到：

```text
MainPID=1818
ExecStart=/nix/store/3bgw9gngk7xskkqrarv71jvm1x3bq9ry-noctalia-shell-4.7.7/bin/noctalia-shell
FragmentPath=/home/vitus/.config/systemd/user/noctalia-shell.service
```

运行时 Shell 目录为
`/nix/store/3bgw9gngk7xskkqrarv71jvm1x3bq9ry-noctalia-shell-4.7.7/share/noctalia-shell`。这是
**Shell 4.7.7 + 本地 overlay 补丁**，不能称为未修改的上游原版。

`noctalia-shell --version` 返回 `noctalia-qs 0.0.12` 不矛盾：上述 nixpkgs 打包把 `noctalia-shell`
链接到 `noctalia-qs/bin/qs`，再添加 Shell QML 路径参数；其 `--version` 是执行引擎版本，不是 QML
Shell 版本。[打包依据](https://github.com/NixOS/nixpkgs/blob/8ce4ef6cb6f871616146b9fe26d2a5ae594e94fe/pkgs/by-name/no/noctalia-shell/package.nix)

## 2. 字段从哪里来，各是什么意思

链路是 Niri IPC JSON → noctalia-qs C++ 模型 → `NiriService.qml` → `Workspace.qml.localWorkspaces` →
`WorkspacePill.qml`。

| 最终字段     | Niri JSON / 计算来源                 | 含义与参与的决策                                                                                        |
| ------------ | ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `id`         | `id`                                 | 跨重排、跨显示器保持的工作区身份；不是显示编号                                                          |
| `idx`        | `idx`                                | 所在显示器上的当前位置编号；可随重排改变，不同显示器可重复；`labelMode=index` 显示它                    |
| `output`     | `output`                             | 显示器名称；决定此 bar 实例是否展示该工作区                                                             |
| `isFocused`  | `is_focused`                         | 所有输出中唯一 focused 工作区；决定 focused 颜色，并使空的当前工作区免于被隐藏                          |
| `isActive`   | `is_active`                          | 各个输出当前可见的工作区，每个输出各有一个；决定胶囊拉长                                                |
| `isUrgent`   | `is_urgent`                          | 该工作区存在 urgent 窗口；决定非 hover、非 focused 时的错误色                                           |
| `isOccupied` | `active_window_id` 非 null/undefined | C++ 模型用是否有 active window 推导；增量更新时用 `activeWindowId >= 0`；不是由工作区名、编号或红色推导 |

来源：[Niri IPC Workspace 定义](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/niri-ipc/src/lib.rs#L1405-L1444)、[noctalia-qs JSON 映射](https://github.com/noctalia-dev/noctalia-qs/blob/e7224b756dcd10eec040df818a4c7a0fda5d6eff/src/wayland/niri/ipc/workspace.cpp#L10-L39)、[NiriService 工作区映射](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Services/Compositor/NiriService.qml#L103-L129)、[Widget 复制字段](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Widgets/Workspace.qml#L326-L372)

特别注意：`active_window_id` 指该工作区自己的 active
window，不表示这个窗口此刻拥有全局键盘焦点。因此工作区 6 明明不是当前焦点，但有微信、Slack，仍然是 occupied，不应理解成 empty。

## 3. 数字胶囊的颜色、大小与标签

### 3.1 颜色优先级

背景和文字分别沿完全相同的状态顺序执行：

| 优先级 | 条件                          | 背景                                      | 文字                               |
| ------ | ----------------------------- | ----------------------------------------- | ---------------------------------- |
| 1      | `pillMouseArea.containsMouse` | `Color.mHover`                            | `Color.mOnHover`                   |
| 2      | `workspace.isFocused`         | `resolveColorKey(focusedColor)`           | `resolveOnColorKey(focusedColor)`  |
| 3      | `workspace.isUrgent`          | **硬编码 `Color.mError`**                 | **硬编码 `Color.mOnError`**        |
| 4      | `workspace.isOccupied`        | `resolveColorKey(occupiedColor)`          | `resolveOnColorKey(occupiedColor)` |
| 5      | 其余                          | `alpha(resolveColorKey(emptyColor), 0.3)` | `resolveOnColorKey(emptyColor)`    |

来源：[WorkspacePill.qml:85-137](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Extras/WorkspacePill.qml#L85-L137)。

所以：鼠标停在胶囊上，hover 会覆盖 focused/urgent 的底色；focused 与 urgent 同为 true 时，focused 暂时遮盖 urgent，而不是从数据上清除了 urgent。切走以后剩余 urgency 又可显示成红色。

本机当前设置见
`home/linux/gui/base/noctalia/config/settings.json:79-96`：`focusedColor=primary`、`occupiedColor=secondary`、`emptyColor=secondary`、`showApplications=false`、`showApplicationsHover=false`。会话主调查者读取运行配色得到：primary
`#99cbff`、secondary `#b9c8da`、error `#ffb4ab`、hover
`#d4bee6`；这些是当次本机值，不是上游固定色值。当前
`useWallpaperColors=true`，不能把“蓝/灰/红”的具体 RGB 当成稳定状态接口。

### 3.2 拉长与颜色是两条独立决策

`WorkspacePill` 的 active state 仅检测 `workspace.isActive`；`getWorkspaceWidth/Height` 用 active 的
`2.2`
倍基准尺寸，另为文字保留足够宽度。因此数字标签存在时最终宽度也受文字长度影响，不保证严格 2.2 倍。[形状状态](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Extras/WorkspacePill.qml#L30-L53)、[尺寸函数](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Widgets/Workspace.qml#L163-L192)

`labelMode=index` 返回 `workspace.idx.toString()`，不是截取 `1terminal`、`2browser`
这样的工作区名。当前名字前缀与 idx
1–10 匹配只是本机布局情况；不能据此把名称前缀当作该模式实现。[标签逻辑](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Extras/WorkspacePill.qml#L102-L116)

## 4. monitor、focused 与 active 的关系

Niri 的定义是 **每个输出一个 active，但全局只有一个 focused**。因此另一块显示器上的可见工作区可以
`isActive=true, isFocused=false`：它仍拉长，却不会取 focused 颜色；如果它有 urgent 窗口且不在 hover，就能显示拉长的红色胶囊。这是两个字段的正常组合，而不是高亮算法自相矛盾。[Niri 字段文档](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/niri-ipc/src/lib.rs#L1434-L1441)、[noctalia-qs 激活处理](https://github.com/noctalia-dev/noctalia-qs/blob/e7224b756dcd10eec040df818a4c7a0fda5d6eff/src/wayland/niri/ipc/connection.cpp#L187-L217)

Widget 筛选显示器时：

- `followFocusedScreen=false`：展示 `ws.output` 与本 bar 的 `screen.name`
  相同的工作区，不区分大小写。
- `followFocusedScreen=true`：先找到 focused 工作区的 output，再展示该输出的工作区，不是把所有屏幕的 active 工作区合成一列。
- 代码还有 `CompositorService.globalWorkspaces`
  的通用旁路，用于全局工作区 compositor；不应把它误认为 Niri 的每屏编号规则。
- `hideUnoccupied=true` 时，只有 `!isOccupied && !isFocused` 才被跳过；空的 focused 工作区仍保留。

来源：[Workspace.qml:326-348](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Widgets/Workspace.qml#L326-L348)。本机
`followFocusedScreen=false, hideUnoccupied=true`。

## 5. urgent 在哪里产生、如何清除

### 5.1 工作区是窗口集合的 OR，不是“访问过就清空”

Niri 26.04 `Workspace::is_urgent()` 的完整逻辑是：

```rust
pub fn is_urgent(&self) -> bool {
    self.windows().any(|win| win.is_urgent())
}
```

来源：[workspace.rs:1828-1830](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/layout/workspace.rs#L1828-L1830)。

Niri 的 `Mapped::set_is_focused()` 在本窗口 focused 状态真正改变时，将 **本窗口**
`self.is_urgent=false`；相同 focused 状态重复设置时直接返回。`set_urgent(true)`
则拒绝给当前已 focused 的窗口设置 urgent。[聚焦变化清除](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/window/mapped.rs#L390-L398)、[设置 urgency 的 guard](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/window/mapped.rs#L601-L613)

因此，“切到工作区 2 并聚焦一个 Zen 窗口”不能保证清空四个 Zen 窗口的 urgency。其余始终未聚焦的 urgent 窗口仍可让聚合值为 true；focused 配色会暂时盖住红色，切走又看到红色。这是源码推导，**本次没有逐个点击来改变用户的焦点或确认清除效果**。关闭最后一个 urgent 窗口也会使
`any(...)` 不再成立，但本次没有执行关闭操作。

### 5.2 Niri 发什么事件

Niri 在刷新 IPC 状态时比较当前与旧的 workspace urgency，变化就发
`WorkspaceUrgencyChanged { id, urgent }`；窗口状态变化则有
`WindowUrgencyChanged { id, urgent }`。工作区名称、idx、output 等无法用现有增量事件表达的变更，才走
`WorkspacesChanged`
全量快照；因此不能只等快照来追踪 urgency。[工作区事件生成](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/ipc/server.rs#L620-L680)、[窗口 urgency 事件](https://github.com/niri-wm/niri/blob/8ed0da44d974c32c6877d2f4630c314da0717ecb/src/ipc/server.rs#L738-L753)

## 6. 本地已有补丁：覆盖什么，不覆盖什么

本仓库 `overlays/noctalia-shell/default.nix:8-14` 注入：

```qml
function onRawEvent(event) {
  if (event.type === "WorkspaceUrgencyChanged")
    Niri.refreshWorkspaces();
}
```

上游 noctalia-qs 0.0.12 的 `onEvent()` 确实没有给 `WorkspaceUrgencyChanged`、`WindowUrgencyChanged`
配专用 handler，但仍对所有事件发出 `rawEvent`；QML 原版 `NiriService` 未订阅这类 raw
urgency 事件。[C++ dispatch 与 rawEvent](https://github.com/noctalia-dev/noctalia-qs/blob/e7224b756dcd10eec040df818a4c7a0fda5d6eff/src/wayland/niri/ipc/connection.cpp#L137-L179)、[原版 QML Connections](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Services/Compositor/NiriService.qml#L43-L76)

`refreshWorkspaces()` 发送 `Workspaces` 请求，重新读取各工作区的 `is_urgent`，更新模型并发
`workspacesUpdated`，再被 `NiriService` 转成
`workspaceChanged`。[主动刷新](https://github.com/noctalia-dev/noctalia-qs/blob/e7224b756dcd10eec040df818a4c7a0fda5d6eff/src/wayland/niri/ipc/connection.cpp#L503-L519)、[刷新模型](https://github.com/noctalia-dev/noctalia-qs/blob/e7224b756dcd10eec040df818a4c7a0fda5d6eff/src/wayland/niri/ipc/connection.cpp#L577-L626)、[QML 更新](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Services/Compositor/NiriService.qml#L46-L49)

覆盖范围：

- 同步工作区 urgency **设置与清除**，不是只刷新 true。
- 针对的是“compositor 已 false、Shell 缓存还 true”的状态不同步问题。
- 不调用 Niri 的窗口焦点动作，不把任何真实 urgency 改成 false。
- 不增加 `WindowUrgencyChanged` 的窗口级模型处理。数字胶囊依据 workspace
  urgency，不直接遍历窗口 urgency；只要聚合值没改变，它继续红色本来就是正确结果。
- 本次主调查者读取运行目录的
  `Services/Compositor/NiriService.qml:59-62`，确认上述 handler 已在运行包内。当前 Niri workspace
  2 本身仍 true，因此该补丁与本次红底并不冲突。

此前问题记录在 [noctalia-workspace-urgent.md](noctalia-workspace-urgent.md)。旧记录中的“focused >
urgent > occupied > empty”省略了 hover；讨论完整渲染顺序应以前述五级为准。

## 7. 官方 issue 调查结果与边界

在官方 `noctalia-dev/noctalia` 与 `noctalia-dev/noctalia-qs` issue 中检索
`niri urgent`、`urgent workspace`、`urgency`、`WorkspaceUrgencyChanged`、`niri highlight`。本轮**没有找到可直接对应“4.7.7
/ qs
0.0.12 漏处理 WorkspaceUrgencyChanged 导致缓存红底”的官方 issue**；这一缺口在本报告由锁定版本源码证明，不编造上游 issue 号，也不据此宣称上游不存在此类报告。[官方精确事件检索](https://github.com/search?q=repo%3Anoctalia-dev%2Fnoctalia+WorkspaceUrgencyChanged&type=issues)、[qs 检索](https://github.com/search?q=repo%3Anoctalia-dev%2Fnoctalia-qs+niri+urgent&type=issues)

查到的相邻问题是
[官方 issue #4459](https://github.com/noctalia-dev/noctalia/issues/4459)：托盘点击未先提供
`ProvideXdgActivationToken`，报告称 Niri 会把无有效输入 serial 的 activation 请求降为“只置 urgent、不聚焦”。该 issue 在本轮读取时为 OPEN，创建于 2026-09-16，最新更新为 2026-11-10。**它报告的是 v5
C++ 实现，不是本机 4.7.7
QML 的补丁失效证据，也不能据此认定当前四个 Zen 窗口的 urgency 来自托盘点击。**
它说明“应用请求激活而得到 urgent”与“Shell 缓存假红”应分开调查。应用为什么提出这些请求，本次没有采集足够历史事件，不能从当前快照还原。

## 8. 仅配置能否换成小点，showBadge 到底是什么

4.7.7 的 Workspace Settings 只提供 `focusedColor`、`occupiedColor`、`emptyColor`
三项状态颜色，没有 Workspace 专用 `urgentColor`、`urgentIndicatorStyle`、`urgentDotSize`
或忽略 urgency 的选项；红底和对应文字色由 `WorkspacePill`
硬编码。[设置面板颜色项](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Panels/Settings/Bar/WidgetSettings/WorkspaceSettings.qml#L300-L329)、[胶囊渲染](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Extras/WorkspacePill.qml#L85-L137)

- `showBadge` 仅参与 grouped 模式的
  `groupedWorkspaceNumberContainer.visible`，这个 badge 是整个工作区的编号，不是独立的 urgent 小红点。[条件](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Widgets/Workspace.qml#L860-L903)
- 非 grouped 的横向/纵向 `WorkspacePill` delegate 没有传入 `showBadge`，组件本身也不定义它。故当前
  `showApplications=false` 时改 `showBadge=false`
  **不会消除红底**。[delegate](https://github.com/noctalia-dev/noctalia/blob/3abfa1fc09b62dc4cdeeb7b787886f075696f0b7/Modules/Bar/Widgets/Workspace.qml#L614-L683)
- 改为 `showApplications=true` 会换成应用图标分组布局，配合 `showBadge=false`
  可隐藏那枚编号 badge，但这既改变了布局，也不是把当前红胶囊转换成小点。
- 全局修改 `mError`
  只能改变所有使用错误语义颜色的地方，不能改变该 widget 的状态优先级或绘制出小点。因此不应作为局部高亮修正推荐。

**结论：如需求是“当前数字胶囊布局不变；只有当前工作区大面积强调；urgent 仅用小点/边框”，需要有针对性的 QML 设计变更；此次调研不实施该变更。**

## 9. 本机截图对应状态（Apollo，会话只读采样）

以下由本次会话主调查者读取 Niri 工作区、窗口列表与运行包，并向本报告汇总；不是从颜色猜测，不是本报告执行交互测试的结果。

| 工作区 | 窗口                                     | focused / active | urgent                              | 截图解释                                    |
| ------ | ---------------------------------------- | ---------------- | ----------------------------------- | ------------------------------------------- |
| 1      | foot、Delta，共 2 个；当前聚焦窗口 id 15 | true / true      | false，urgent 窗口 0 个             | primary 蓝底；active 导致拉长               |
| 2      | Zen，共 5 个                             | false / false    | true；窗口 id 7、8、9、10 各自 true | urgent 分支抢先于 occupied，整块 error 红底 |
| 6      | 微信、Slack，共 2 个                     | false / false    | false，urgent 窗口 0 个             | occupied 的 secondary 灰蓝底，不是空工作区  |

本机
`hideUnoccupied=true`，其余空且非 focused 的工作区被隐藏，故该 bar 只出现 1、2、6。`labelMode=index`，当前命名前缀恰与 1–10 的 idx 对应。以上解释同时满足形状、颜色、隐藏条件，无需把截图归咎为单一“高亮色没调对”。

本轮未切换工作区、未逐个聚焦 Zen、未关闭窗口、未重启 Shell、未修改 urgency 或主题。因此可以确认“当前数据与当前红底一致”，但不声称已经完成“聚焦四个窗口后全部清红”的现场验证。
