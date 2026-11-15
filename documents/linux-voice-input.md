# Linux 语音输入

Linux Niri 桌面统一使用 Voiceless。Home Manager 导入 Voiceless 自带模块，安装 CUDA 版
`voiceless.packages.${system}.voiceless`，启用常驻 daemon 与 eww 浮层，并加入 Fcitx5 桥接。配置入口是
`home/linux/gui/base/voice-input.nix`；版本由 `flake.lock` 固定。

## 常驻识别与快捷键

当前记录的本地识别方案为 `[asr] streaming_backend = "local-offline"`，模型 `qwen3-asr-1.7b-gguf`
通过 transcribe.cpp/CUDA 在 GPU 上推理，约占 2.5 GB 显存。Silero
VAD 按停顿切句，当前句每 0.5 秒重算用于实时显示，松手后生成最终结果。引擎、模型与云端整理选项仍由仓库外的用户配置决定；本仓库不改写这些选择。

`voiceless.service`
启动时将模型加载进显存；控制命令只向 daemon 发指令，避免为每次识别重复加载模型。daemon 的
`[hotkey] key` 可直接读取 ScrollLock，需要用户属于 `input` 组并重新登录：

- 按住 ScrollLock 说话，或短按切换识别状态。
- Ctrl+ScrollLock 使用整理模式。
- Niri 的 `Mod+Shift+D` 调用 `voiceless ctl toggle`，作为不依赖 input 组的应急入口。

Niri 不提供按键松开动作，因此 ScrollLock 的按住说话由 daemon 处理，不在 Niri 重复绑定。快捷键配置位于
`home/linux/gui/niri/conf/keybindings.kdl`。

`voiceless stream` 在 daemon 运行且使用本地后端时把会话交给 daemon，复用已加载的模型。带 `--config`
或 `--backend` 时独立运行；输出、Ctrl-C 取消和 `--no-inject` 继续适用。

## 上屏与浮层

`voice-input.nix` 用本机 Nixpkgs 编译 `voiceless-fcitx5-bridge`，保持 Fcitx5 C++ ABI 一致。桥接在
`org.fcitx.Fcitx5` 的 `/voiceless` 暴露 `dev.voiceless.Fcitx5Bridge1.CommitString`。

`inject.prefer = "fcitx5"`
时，识别中的文本通过桥接显示为输入框预编辑，最终文本由 Fcitx5 提交。Wayland（含新版微信）与 XWayland 应用均走当前输入法通道；桥接失败时，由用户配置的
`clipboard_fallback = true` 控制剪贴板回退。

Voiceless 包的 wrapper 自带录音和注入工具，不在全局额外安装 wtype 或重复声明 wl-clipboard。桌面公共剪贴板仍由
`desktop-tools.nix`
安装 wl-clipboard；语音模块保留 xsel、xdotool，供微信等 XWayland 应用使用 X11 剪贴板回退。

浮层由导入的 Home Manager 模块管理，服务为 `voiceless-overlay-eww.service` 和
`voiceless-overlay.service`，配置在 `~/.config/eww-voiceless`。旧的手动克隆 `~/.config/eww`、Python
pump 和 `voiceless-web.service` 不再是当前部署前提。

## 用户配置、模型与控制台

`~/.config/voiceless/config.toml`
含云端密钥等用户选择，不由本仓库管理；模型与历史位于用户的数据目录，不写入 Git 或 Nix
store。本轮依赖清理不读取或删除这些文件。

浏览器打开
<http://127.0.0.1:8790/>，由常驻 daemon 提供控制台，可查看识别状态、控制开始/停止、管理引擎与模型、词库、模式和提示词、测试快捷键与上屏、查看历史及诊断结果。
`[text]` 可清理语气词，热词支持拼音纠错与识别偏置。

使用本地识别前，在控制台或 Voiceless 模型管理器安装当前选择的模型。切换云端识别或文本整理时，在用户配置中提供相应服务设置；CUDA 包的声明不代表所有会话都必须使用本地后端。

## 验证

配置变更后可检查：

```bash
niri validate
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.programs.voiceless.enable
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.programs.voiceless.package.pname --raw
```

在已部署的桌面会话中检查服务、模型与桥接：

```bash
systemctl --user is-active voiceless.service voiceless-overlay-eww.service voiceless-overlay.service
voiceless doctor
voiceless ctl status
busctl --user call org.fcitx.Fcitx5 /voiceless dev.voiceless.Fcitx5Bridge1 Status
journalctl --user -u voiceless
```

实际验收应覆盖 ScrollLock 与应急快捷键、中文实时预编辑和最终提交、Wayland 与 XWayland 输入框、桥接不可用时的剪贴板回退，以及 daemon 常驻后显存不会为每次识别重复增长。这些是建议的验收场景，不表示本轮清理已运行或通过。

## 调整与回滚

仅调整上屏方式时，在用户配置中把 `inject.prefer` 改为 `"clipboard"`。需要恢复全局 wtype 时，可在
`voice-input.nix`
显式加入该包；当前 wrapper 已提供的工具无需重复安装。修改应用来源或版本时更新 Voiceless input 与
`flake.lock`，重新部署，再检查上述服务与桥接。不要为回滚删除用户配置、模型或历史。

## 参考资料

- [Voiceless](https://github.com/Vitus213/voiceless)
- [Niri 键绑定](https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings)
- [Fcitx5 与 Rime](./fcitx5-rime-input-method.md)
