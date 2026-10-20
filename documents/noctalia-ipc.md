# Noctalia IPC 与服务环境

## 当前配置

- Noctalia 由 home-manager 的 `systemd.user.services.noctalia-shell` 启动，配置入口
  `home/linux/gui/base/noctalia/default.nix`。
- 服务环境中 `QT_QPA_PLATFORM=wayland`，与会话变量（`home/linux/gui/base/desktop-tools.nix` 的
  `home.sessionVariables`）保持一致。
- niri 快捷键（如 `Alt+Space` 打开 launcher）、hypridle 锁屏等都通过 `noctalia-shell ipc call ...`
  与运行中的实例通信。

## 约束

`noctalia-qs`（quickshell fork，当前 0.0.12）执行 `ipc` / `list` 时，会按 `QT_QPA_PLATFORM`
推导的 display connection 过滤实例。如果服务端和调用端的值不同（例如服务设为 `wayland;xcb`、会话为
`wayland`），实例 display 会记录为 `unk,`，调用端会报：

```
No running instances for ".../noctalia-shell/shell.qml"
```

表现就是 Alt+Space 等快捷键没有任何反应。修改任何一侧的 `QT_QPA_PLATFORM` 时，两侧都要同步改。

## 排查

```bash
noctalia-shell list --all                                # 查看实例及 Display connection
noctalia-shell list                                      # 按当前环境过滤，为空说明 display 不匹配
noctalia-shell ipc --any-display call launcher toggle    # 临时绕过过滤
systemctl --user show noctalia-shell -p Environment
```

## 生效与回滚

- rebuild 后需要执行 `systemctl --user restart noctalia-shell`（或重新登录）才会应用新的服务环境。
- 回滚：把服务中的 `QT_QPA_PLATFORM` 改回原值，并在所有 `noctalia-shell ipc` 调用中加
  `--any-display`。
