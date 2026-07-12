# Fcitx5 与 Rime 小鹤双拼

本文记录 NixOS 桌面当前输入法配置的使用方式、配置入口、验证和回滚方法。

## 当前方案

日常输入只使用 Fcitx5 的 `rime` 输入法，不再在 Fcitx5 层面把 `rime` 和英文键盘 `en` 来回轮转。

- `Ctrl+Space`：Rime 内部切换小鹤双拼的 `中` / `Ａ`。
- `Ctrl+Alt+Space`：Fcitx5 救援激活/关闭键。
- `Shift`：不参与输入法切换。
- `CapsLock`：保持系统原生大写锁定功能，不参与输入法切换。

Fcitx5 的 Default 输入法组只保留 `rime`。`en` 是 Fcitx5 的键盘输入法，不是 Rime 的西文状态；Rime 的
`Ａ` 是小鹤双拼方案内部的 `ascii_mode`。

## 为什么不用 Shift 切换

Fcitx5 和 Rime 都可能处理 Shift：

- Fcitx5 默认有临时切换输入法的 Shift 行为，容易在 Rime 之前把当前输入法切到 `en`。
- Rime 的 `ascii_composer/switch_key` 支持 Shift，但 Shift 本身也是大小写、选择和快捷键修饰键。
- 在当前桌面前端组合中，Shift 观察到的是按住时临时变化、松开后恢复，不适合作为稳定的中西文切换键。

因此当前配置禁用 Shift 参与中西文切换，只保留 `Ctrl+Space` 作为稳定入口。

## 配置入口

- `home/linux/gui/base/fcitx5/config`：Fcitx5 全局快捷键。
- `home/linux/gui/base/fcitx5/profile`：Fcitx5 输入法组。
- `home/linux/gui/base/fcitx5/default.custom.yaml`：Rime 用户补丁。
- `home/linux/gui/base/fcitx5/default.nix`：Home Manager 链接入口。

关键配置如下：

```ini
[Hotkey]
AltTriggerKeys=
EnumerateForwardKeys=
EnumerateBackwardKeys=
EnumerateGroupForwardKeys=
EnumerateGroupBackwardKeys=
ActivateKeys=
DeactivateKeys=

[Hotkey/TriggerKeys]
0=Control+Alt+space
```

```yaml
patch:
  schema_list:
    - schema: double_pinyin_flypy
  ascii_composer/switch_key/Caps_Lock: noop
  ascii_composer/switch_key/Control_L: noop
  ascii_composer/switch_key/Control_R: noop
  ascii_composer/switch_key/Shift_L: noop
  ascii_composer/switch_key/Shift_R: noop
  key_binder/bindings/+:
    - { accept: Control+space, toggle: ascii_mode, when: always }
```

## 重启与重新部署

当前会话中的 Fcitx5 只由 Home Manager 的 `fcitx5-daemon.service` 启动。用户级
`org.fcitx.Fcitx5.desktop` 设置 `Hidden=true`，用于禁止系统 XDG
autostart 创建重复实例。重启当前生效的 Fcitx5：

```bash
systemctl --user restart fcitx5-daemon.service
```

重新部署 Rime 配置：

```bash
rm -rf ~/.local/share/fcitx5/rime/build
mkdir -p ~/.local/share/fcitx5/rime/build
rime_deployer --build \
  ~/.local/share/fcitx5/rime \
  "$(dirname "$(find /nix/store -path '*/share/rime-data/fcitx5.yaml' | head -1)")" \
  ~/.local/share/fcitx5/rime/build
```

如果 `rime_deployer` 不在 `PATH` 中，使用当前系统中的 librime 路径执行。

## 验证

检查 Fcitx5 当前状态：

```bash
fcitx5-remote -n
fcitx5-remote -q
fcitx5-remote
```

期望结果：

```text
rime
Default
2
```

检查唯一启动服务和 XWayland XIM 注册：

```bash
systemctl --user is-active fcitx5-daemon.service
nix shell nixpkgs#xprop -c xprop -root XIM_SERVERS
```

期望分别得到 `active` 和 `XIM_SERVERS(ATOM) = @server=fcitx`。

检查 Rime 生成配置：

```bash
rg -n 'Shift_R|Control\+space|ascii_mode' ~/.local/share/fcitx5/rime/build/default.yaml
```

期望包含：

```text
Shift_R: noop
Control+space
toggle: ascii_mode
```

## 回滚

如需恢复 Fcitx5 英文键盘轮转，可在 `home/linux/gui/base/fcitx5/profile` 的 Default 组重新加入
`keyboard-us`。如需恢复 Shift 行为，可在 `default.custom.yaml` 中调整
`ascii_composer/switch_key/Shift_L` 或 `Shift_R`，然后重新部署 Rime。
