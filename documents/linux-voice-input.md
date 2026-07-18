# Linux 语音输入

本文记录 `apollo` 的 NixOS + Niri Wayland 语音输入方案。配置位于 Linux GUI Home
Manager 基础模块，也会进入使用该模块的同类桌面会话。

## 当前结论

Type4Me 是 Niri 唯一的全局语音输入入口。

- Type4Me 源码输入：`path:/home/vitus/type4me-linux`
- Home Manager 配置：`home/linux/gui/base/voice-input.nix`
- Niri 快捷键：`home/linux/gui/niri/conf/keybindings.kdl`
- Type4Me 版本：`0.1.0`
- Niri 版本：`26.04`

Type4Me 使用本地 SenseVoice、Silero VAD 和 Qwen3-ASR 模型，最终文本优先通过 `wtype`
注入当前 Wayland 客户端，失败时回退到 `wl-copy`。

## 当前行为

Home Manager 安装 Type4Me、`wtype`、`wl-clipboard`、`libnotify` 和
`playerctl`，并启动 Type4Me 用户服务：

```bash
systemctl --user status type4me-linux.service
```

`type4me-linux.service` 在 Wayland 图形会话中执行：

```text
type4me-linux gui --background
```

服务导出 `io.github.vitus.Type4Me.Controller` D-Bus 接口。Niri 快捷键直接调用该接口：

- `Scroll Lock`：调用 `Toggle`，开始或停止录音
- `Shift + Scroll Lock`：调用 `Cancel`，取消当前录音

两个绑定都设置
`repeat=false`。Niri 当前不提供按键松开动作，因此不配置按住说话；切换模式是该合成器上可确定实现的行为。

## Portal 后备原因

Type4Me GUI 会优先请求 `org.freedesktop.portal.GlobalShortcuts`。当前会话的 Portal 前端报告版本
`1`，但实际组合是 Niri 26.04、`xdg-desktop-portal-gnome` 和 `xdg-desktop-portal-gtk`。真实
`CreateSession` 成功后，`BindShortcuts` 返回响应码
`2`，即请求未完成；停止其他 Type4Me 会话后单独重试结果相同。

因此 Niri 使用 compositor 配置中的 D-Bus 绑定。它不模拟 Portal 授权，也不依赖 X11 键盘抓取。以后若 Portal 后端能成功绑定，可继续使用 GUI 中的“绑定快捷键”，Niri 后备绑定仍可保留。

## 模型

Type4Me 的三个默认模型由应用自己的模型管理器安装和校验：

```bash
type4me-linux model install sensevoice-int8
type4me-linux model install silero-vad
type4me-linux model install qwen3-asr-0.6b-int8
type4me-linux model list
type4me-linux doctor
```

模型进入 Type4Me 的 XDG 数据目录，不写入 Git 或 Nix
store。GUI 的“模型”页面也提供同一套安装和状态检查功能。

## 验证

配置级检查：

```bash
niri validate
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.systemd.user.services.type4me-linux.Service.ExecStart --json
```

运行时检查：

```bash
systemctl --user is-active type4me-linux.service
busctl --user introspect io.github.vitus.Type4Me \
  /io/github/vitus/Type4Me io.github.vitus.Type4Me.Controller
```

本次接入已确认：

- Niri 接受两条新 KDL 绑定。
- Apollo Home Manager 求值生成 Type4Me Nix store `ExecStart`。
- Type4Me flake 包构建成功。
- 当前会话服务为 `active`，D-Bus 导出 `Toggle`、`Cancel`、`HoldStart`、`HoldStop` 和 `ShowWindow`。
- 实际调用一次 `Toggle` 和 `Cancel` 均成功返回。

## 已知限制

- `type4me-linux`
  flake 输入当前使用本机绝对路径，适合该个人配置仓库；迁移到其他机器前需要同步源码或改为可访问的远程 flake
  URL。
- 当前 Portal 后端不能完成 GlobalShortcuts 绑定，Niri 快捷键是主控制路径。
- Niri 没有按键松开绑定，所以只提供切换与取消，不提供按住说话。
- Type4Me 模型需要单独安装；缺少模型时 GUI 和控制服务仍可启动，但识别不能完成。

## 回滚

从 `flake.nix` 移除 `type4me-linux` 输入，从 `voice-input.nix` 移除 Type4Me 包和用户服务，并从
`keybindings.kdl` 删除两条 Type4Me 绑定。重新部署后，系统将不再提供全局语音输入。

## 参考资料

- [Type4Me Linux](https://github.com/vitus/type4me-linux)
- [Niri 键绑定](https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings)
- [XDG Desktop Portal GlobalShortcuts](https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.GlobalShortcuts.html)
