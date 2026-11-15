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

只安装当前使用的 Rime、GTK 集成与 Fcitx5 配置工具，不再安装 Mozc/Hangul
addon 或声明 Mozc 配置链接。旧用户数据不由本轮清理删除。Rime 数据使用 Nixpkgs 的
`rime-ice`，用户补丁通过 `__include: rime_ice_suggestion:/`
继承该包的建议配置，再覆盖小鹤双拼与快捷键。

macOS Squirrel 入口为 `home/darwin/rime-squirrel.nix`，同样使用上游数据与小鹤双拼补丁。
`Library/Rime` 数据目录及独立 `default.custom.yaml` 均不设置
`force`，避免父目录的强制覆盖使子文件跳过碰撞检查。现有文件使用 Home Manager 的
`home-manager.backup`
备份扩展名；若同名备份已经存在，激活停止，需先手工整理并保留用户自定义与备份再部署。

2026-11-16 使用锁定 Home Manager `b787c48` 的实际碰撞检查脚本在临时目录验证：旧父目录 `force`
会跳过冲突，新配置拒绝已有补丁与备份同时存在的激活，两个文件内容均保留；无旧备份时允许标准备份流程。此为 Linux 上的脚本冒烟，未执行 macOS 激活或输入法交互。

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
- 数据使用 nixpkgs 的 `pkgs.rime-ice`（2026.06.30）；overlay 仅为 Fcitx 设置
  `rimeDataPkgs`，不改全局 `rime-data`。

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
  __include: rime_ice_suggestion:/
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

## 微信接入

微信 `4.1.13.26` 使用原生 Wayland，应用局部设置
`QT_IM_MODULE=text-input-unstable-v3`。Fcitx5 与 Rime 小鹤双拼保持不变，不需要迁移中文引擎。XWayland 启动探测和 XIM 恢复服务继续为 X11 应用保留，不作为新版微信的输入前提。微信候选框和截图粘贴分别验收，详见
[Linux 微信、QQ 与飞书](./linux-im-apps.md)。

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
