# Noctalia IPC 与服务环境

仓库固定 Noctalia **5.5.0**，apollo 已完成挂载顺序修正版的
`switch`，运行系统与开机 profile 一致。新服务、IPC 与通知 D-Bus 正常，真实错误/正确密码解锁已验收。迁移状态、验证范围与回滚见
[Noctalia v5 专题](./noctalia-v5.md)。

## 服务与环境

配置入口为 `home/linux/gui/base/noctalia/default.nix`，使用 `pkgs.noctalia`，由 Home Manager 声明
`noctalia.service`：

- `Type=notify`，以前台 `noctalia` 为 `ExecStart`，`Restart=on-failure`；不使用 `--daemon`。
- `After=niri.service`、`Before=graphical-session.target`、`PartOf=graphical-session.target`，由
  `WantedBy=niri.service` 拉起；就绪通知用于在 Shell ready 后放行后续会话启动。
- 服务只显式设置 `TERMINAL=kitty`，值不带 `-e`。v5 原生 Shell 不依赖旧 Quickshell 的 Qt display
  connection 过滤，也不使用 `NOCTALIA_PAM_SERVICE`；专用 PAM 服务由本地包补丁绑定。

`[shell] launch_apps_as_systemd_services=true` 让启动器打开的应用运行在独立 transient user
service 中。已实际验证启动器启动的 kitty 心跳任务在 Shell 重启后继续运行，`Terminal=true`
入口也由 kitty 正常执行。其他应用的全局 Qt 环境与 qt6ct 配置独立保留。

## 快捷键与 IPC

v5 入口统一为 `noctalia msg ...`。活动 Niri 配置已写入下表命令并通过
`niri validate`；物理全局快捷键尚未验收。

| 入口                               | 命令                                                                                                  |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `Alt+Space`、`Mod+D`、`XF86Search` | `noctalia msg panel-toggle launcher`                                                                  |
| `Mod+C`                            | `noctalia msg panel-toggle launcher /calc`                                                            |
| `Mod+Shift+V`                      | `noctalia msg panel-toggle clipboard`                                                                 |
| `Mod+S` / `Mod+E`                  | `noctalia msg panel-toggle control-center` / `noctalia msg panel-toggle session`                      |
| `Ctrl+Alt+L`、hypridle 锁屏        | `noctalia msg session lock`                                                                           |
| 音量增加 / 减少                    | `noctalia msg volume-up 1` / `noctalia msg volume-down 1`                                             |
| 扬声器 / 麦克风静音                | `noctalia msg volume-mute` / `noctalia msg mic-mute`                                                  |
| 亮度增加 / 减少                    | `noctalia msg brightness-up current 3` / `noctalia msg brightness-down current 3`                     |
| 播放 / Stop / 上一首 / 下一首      | `noctalia msg media toggle` / `pause` / `previous` / `next`（后三项同样带 `noctalia msg media` 前缀） |

Stop 保持原有 pause 语义。锁屏命令立即锁定，菜单倒计时与免密 grace 是不同设置；本配置
`grace_period_seconds=0`。

插件事件语法为 `noctalia msg plugin <author/plugin:entry> <target> <event> [payload]`。`focused`
只选择焦点输出上的 entry；`all` 广播到全部匹配实例，singleton service / panel 必须使用
`all`。TOTP 操作只发给 `focused`，避免多屏重复复制或切换：

```bash
noctalia msg plugin vitus/desktop:totp focused refresh
noctalia msg plugin vitus/desktop:totp focused copy
noctalia msg plugin vitus/desktop:totp focused select-copy
noctalia msg plugin vitus/desktop:totp focused switch
noctalia msg panel-toggle thepunkoff/pomodoro:panel
noctalia msg plugin thepunkoff/pomodoro:pomodoro all start
```

番茄钟 service 还接受 `pause`、`skip`、`reset`、`reset-all`。没有 v4 命令兼容包装。

## 配置所有权与诊断

基础配置 `~/.config/noctalia/config.toml` 是仓库 TOML 的文件级链接；`plugins.toml`
由 Nix 生成。GUI、IPC 等运行期操作产生的持久化覆盖写入
`~/.local/state/noctalia/settings.toml`，最后加载并覆盖基础层。修改仓库值却未生效时，应检查相同键的 GUI
override；不要在每次 activation 清空整个 state。首次迁移已有 v5 override 的备份安排见专题。

运行时诊断入口：

```bash
systemctl --user show noctalia -p MainPID -p ExecStart -p ActiveState -p Type -p Environment
systemctl --user cat noctalia
journalctl --user -u noctalia -b
noctalia msg status
noctalia msg plugins list
```

排查应先确认实际包路径、服务状态、IPC 与日志，再检查配置覆盖和插件实例；服务定义变更需随系统激活加载，之后才能通过
`systemctl --user restart noctalia` 重启新服务。4.7.7 的 `noctalia-shell list`、`ipc --any-display`
与 Qt 环境同步要求属于旧 Quickshell 历史，不适用于 v5。

## 固定版本来源

- [v5.5.0 systemd 服务与应用隔离](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/compositor-settings/systemd-service.mdx)
- [v5.5.0 IPC 总览](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/ipc/index.mdx)、[系统控制](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/ipc/system-controls.mdx)、[插件事件目标](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/ipc/plugins.mdx)
- [v5.5.0 配置层与覆盖顺序](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/configuration/index.mdx)
