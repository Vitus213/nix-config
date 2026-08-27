# Linux 语音输入

本文记录 `apollo` 的 NixOS + Niri Wayland 语音输入方案。配置位于 Linux GUI Home
Manager 基础模块，也会进入使用该模块的同类桌面会话。

## 当前结论

Type4Me（type4me-linux 0.1.0）是 Niri 唯一的全局语音输入入口。

- Type4Me flake 输入：`github:Vitus213/type4me-linux`，固定到已验证提交
  `3e367432036bbbbb035dbaa6229ecb3ce94ee2d8`
- Home Manager 配置：`home/linux/gui/base/voice-input.nix`
- Niri 快捷键：`home/linux/gui/niri/conf/keybindings.kdl`
- 常驻服务：`type4me-linux.service`（`type4me-linux service`，随 Wayland 会话启动）

Type4Me 是 Python/GObject 实现的本地实时转写应用，基于 sherpa-onnx（x86_64 上启用 CUDA 解码），最终文本优先通过
`wtype` 注入当前 Wayland 客户端，失败时回退到
`wl-copy`；录音与注入工具由包自带的 wrapper 提供，无需另行安装。

## 当前行为

Home Manager 安装 Type4Me 并声明一个随 Wayland 会话启动的用户服务：

- `type4me-linux.service`：`type4me-linux service` 常驻进程，持有 D-Bus 总线名
  `io.github.vitus.Type4Me`

Niri 快捷键通过 D-Bus 调用常驻服务（不额外拉起进程）：

- `Scroll Lock`：`Type4Me.Controller.Toggle` —— 空闲时开始录音，录音时停止并注入最终文本
- `Shift + Scroll Lock`：`Type4Me.Controller.Cancel` —— 取消当前录音

两个绑定都设置 `repeat=false`。D-Bus 对象路径为
`/io/github/vitus/Type4Me`。Niri 当前不提供按键松开动作，因此不配置按住说话。

## 模型

模型由 Type4Me 内置的模型管理逻辑安装和校验（sherpa-onnx 的
`streaming-paraformer-bilingual-zh-en`）。模型数据进入用户数据目录，不写入 Git 或 Nix
store。缺少模型时服务仍可启动，但识别不能完成。

## 验证

配置级检查：

```bash
niri validate
nix eval --raw .#nixosConfigurations.apollo.config.home-manager.users.vitus.systemd.user.services.type4me-linux.Service.ExecStart
```

运行时检查：

```bash
systemctl --user is-active type4me-linux.service
gdbus call --session --dest io.github.vitus.Type4Me \
  --object-path /io/github/vitus/Type4Me \
  --method io.github.vitus.Type4Me.Controller.Toggle
```

## 已知限制

- Niri 没有按键松开绑定，所以只提供切换与取消，不提供按住说话。
- Type4Me flake 的 `main` 分支已演进为 Syllune；本仓库固定到 Type4Me 提交
  `3e36743...`，换回 Syllune 需执行下方回滚并更新锁。
- 模型需要单独安装；更新 Type4Me 前如有本地改动，先推送到 Vitus213/type4me-linux。

## 回滚（换回 Syllune）

1. `flake.nix` 的 `type4me` 输入改回 `syllune = { url = "github:Vitus213/syllune"; ... }`
2. `voice-input.nix` 恢复为 Syllune 版本（`syllune` 包 + `eww-syllune-overlay` / `syllune-web`
   服务）
3. `keybindings.kdl` 两条绑定改回 `$HOME/.config/eww/syllune-overlay-toggle` 脚本调用
4. `nix flake lock --update-input syllune` 并重新部署

## 参考资料

- [type4me-linux](https://github.com/Vitus213/type4me-linux)
- [Niri 键绑定](https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings)
