# Noctalia 工作区 urgent 红色角标不消失

## 现象

Noctalia 顶栏的工作区指示器里，某个工作区（常见是开机后的 `1terminal`）一直显示红色角标；
`niri msg -j workspaces` 中该工作区却是
`is_urgent: false`。停在该工作区时显示为聚焦色，切走后又变红。

## 原因

- 组件版本：niri 26.04、noctalia-shell 4.7.7、noctalia-qs 0.0.12。
- niri 在 urgency 变化时只发增量事件 `WorkspaceUrgencyChanged {id, urgent}`（窗口级为
  `WindowUrgencyChanged`）。
- noctalia-qs 的 Niri IPC（`src/wayland/niri/ipc/connection.cpp`）不处理这两个事件，只在
  `WorkspacesChanged` 快照或主动刷新时读取
  `is_urgent`。某次快照恰好拍到 urgent=true 后，后续的清除事件被丢弃，红色就一直保留到下一次快照或 shell 重启。上游 main 截至 2026-10-26 仍未处理。
- 工作区组件的颜色优先级是“聚焦 >
  urgent > 有窗口 > 空”（`Modules/Bar/Widgets/Workspace.qml`），因此只有切走后才看得到红色。

## 当前配置

`overlays/noctalia-shell/default.nix` 在构建时修改 `Services/Compositor/NiriService.qml`，在
`Connections { target: Niri }` 中加入：

```qml
function onRawEvent(event) {
  if (event.type === "WorkspaceUrgencyChanged")
    Niri.refreshWorkspaces();
}
```

收到 urgency 变化事件时向 niri 重新请求一次工作区列表，urgent 的设置和清除都会同步到顶栏。补丁使用
`substituteInPlace --replace-fail`，noctalia-shell 升级后锚点不存在会直接构建失败，届时检查上游是否已修复再决定是否保留。

## 生效与验证

- `just local` 后执行 `systemctl --user restart noctalia-shell`（或重新登录）。
- 手动触发一次 urgency：

  ```bash
  niri msg action spawn -- foot -o bell.urgent=yes sh -c 'sleep 2; printf "\a"; sleep 4'
  # 立刻 Mod+2 切走：1terminal 变红；切回 1 后 urgent 清除，再切走应不再显示红色
  niri msg -j event-stream   # 可观察 WorkspaceUrgencyChanged 事件
  ```

## 回滚

删除 `overlays/noctalia-shell/` 后重新部署并重启 noctalia-shell。临时清除红色可直接
`systemctl --user restart noctalia-shell`。
