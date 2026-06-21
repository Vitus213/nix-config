# Pomodoro 插件

这是 Noctalia Shell 的番茄钟插件，用于管理专注、短休息和长休息。

## 功能

- session: 支持工作、短休息、长休息
- cycle: 可配置进入长休息前的工作轮数
- session tracking: 记录当前 cycle 内已完成的 session
- auto-start: 可选自动开始休息或工作 session
- compact mode: 更紧凑的面板视图
- custom timer: 支持正计时和倒计时
- bar widget: 显示当前模式和剩余时间
- notifications: session 结束时播放声音并发通知
- time tracking: 记录累计专注时间，内部以秒存储

## 待做

- custom presets: 用户可创建和选择本地 preset
- custom sounds: 用户可选择或添加提示音

## IPC 命令

可以通过 Noctalia IPC 控制插件:

```bash
qs -c noctalia-shell ipc call plugin:pomodoro <command>
```

## 可用命令

| 命令                  | 说明                                             | 示例                                                                   |
| --------------------- | ------------------------------------------------ | ---------------------------------------------------------------------- |
| `toggle`              | 打开或关闭当前屏幕上的番茄钟面板                 | `qs -c noctalia-shell ipc call plugin:pomodoro toggle`                 |
| `start`               | 开始或继续计时                                   | `qs -c noctalia-shell ipc call plugin:pomodoro start`                  |
| `pause`               | 暂停当前计时                                     | `qs -c noctalia-shell ipc call plugin:pomodoro pause`                  |
| `reset`               | 重置当前 session                                 | `qs -c noctalia-shell ipc call plugin:pomodoro reset`                  |
| `resetAll`            | 重置所有 session 并回到工作模式                  | `qs -c noctalia-shell ipc call plugin:pomodoro resetAll`               |
| `skip`                | 跳到下一个阶段                                   | `qs -c noctalia-shell ipc call plugin:pomodoro skip`                   |
| `stopAlarm`           | 停止正在播放的提示音                             | `qs -c noctalia-shell ipc call plugin:pomodoro stopAlarm`              |
| `finish`              | 完成当前 custom timer 并累计时间                 | `qs -c noctalia-shell ipc call plugin:pomodoro finish`                 |
| `abandon`             | 放弃当前 custom timer，不累计时间                | `qs -c noctalia-shell ipc call plugin:pomodoro abandon`                |
| `setTimerType`        | 设置计时类型，`0` 番茄钟，`1` 正计时，`2` 倒计时 | `qs -c noctalia-shell ipc call plugin:pomodoro setTimerType 2`         |
| `setCountdownMinutes` | 设置倒计时分钟数                                 | `qs -c noctalia-shell ipc call plugin:pomodoro setCountdownMinutes 45` |

## 示例

开始番茄钟:

```bash
qs -c noctalia-shell ipc call plugin:pomodoro start
```

提前进入休息:

```bash
qs -c noctalia-shell ipc call plugin:pomodoro skip
```

重置所有状态:

```bash
qs -c noctalia-shell ipc call plugin:pomodoro resetAll
```

## 设置项

这些设置存储在 `settings.json` 中，也可以通过 widget settings 修改。

| 设置项                     | 默认值 | 说明                          |
| -------------------------- | ------ | ----------------------------- |
| `workDuration`             | 25 min | 每个工作 session 时长         |
| `shortBreakDuration`       | 5 min  | 短休息时长                    |
| `longBreakDuration`        | 15 min | 长休息时长                    |
| `sessionsBeforeLongBreak`  | 4      | 进入长休息前的工作 session 数 |
| `autoStartBreaks`          | false  | 工作结束后自动开始休息        |
| `autoStartWork`            | false  | 休息结束后自动开始工作        |
| `compactMode`              | false  | 隐藏圆形进度条                |
| `countdownDurationMinutes` | 25 min | 倒计时默认时长                |
| `totalTrackedSeconds`      | 0      | 持久化累计专注时间，单位为秒  |

## 致谢

`alarm.mp3` 来自 [Pixabay](https://pixabay.com/)，使用 Pixabay Content License。
