# Linux 语音输入

本文记录 `apollo` 的 NixOS + Niri Wayland 语音输入方案。配置位于 Linux GUI Home
Manager 基础模块，也会进入使用该模块的同类桌面会话。

## 当前结论

Voiceless 是 Niri 唯一的全局语音输入入口。

- Voiceless flake 输入：`github:Vitus213/voiceless`，由 `flake.lock` 固定到已验证提交
- Home Manager 配置：`home/linux/gui/base/voice-input.nix`
- Niri 快捷键：`home/linux/gui/niri/conf/keybindings.kdl`
- Voiceless 版本：`0.1.0`
- Niri 版本：`26.04`

Voiceless 是 Rust 实现的实时语音输入工具。当前配置走**云端链路**：流式 ASR 通过 DashScope 的
`qwen3-asr-flash-realtime`（WebSocket 实时接口），文本整理走 OpenAI 兼容接口调
`qwen-flash`。Voiceless 自带 sherpa-onnx 本地推理后端（作为离线后备），当前未启用；因此安装的是 CPU 版包（`voiceless-cpu`），不携带 CUDA 工具链。最终文本优先通过
`wtype` 注入当前 Wayland 客户端，失败时回退到
`wl-copy`；录音、注入工具由 Voiceless 包的 wrapper 自带，无需另行安装。

## 当前行为

Home Manager 安装 Voiceless（CPU 版）、`eww`、`python3`（`lib.lowPrio`，仅为 overlay
pump 提供解释器；PATH 冲突时让位给 editors 的完整 python
env），并声明两个随 Wayland 会话启动的用户服务：

- `eww-voiceless-overlay.service`：`eww daemon`，承载 overlay pill 窗口
- `voiceless-web.service`：`voiceless history serve`，历史记录 Web 控制台，默认监听 `127.0.0.1:8790`

Niri 快捷键不直接调用 Voiceless，而是调用 overlay 触发脚本：

- `Scroll Lock`：空闲时启动 `quick` 模式；识别中则停止会话并注入最终文本
- `Ctrl + Scroll Lock`：空闲时启动 `prompt-optimize`（LLM 整理）模式；识别中不重复启动

两个绑定都设置
`repeat=false`。Niri 当前不提供按键松开动作，因此不配置按住说话；切换模式是该合成器上可确定实现的行为。

触发脚本拉起 Python overlay pump：pump 运行
`voiceless stream --json`，把实时识别文本经 FIFO 推给 eww 的
`deflisten`，在屏幕底部中央显示一个 layer-shell pill，会话结束后自动关闭。

## 仓库外依赖

overlay 的配置与脚本位于 `~/.config/eww/`（独立 Git 仓库 `Vitus213` 名下），**不由本仓库管理**：

- `voiceless-overlay-toggle`：Niri 快捷键的入口脚本
- `voiceless-overlay.py`：`voiceless stream` 与 eww 之间的 pump
- `voiceless-overlay-listen.sh`：eww `deflisten` feeder
- `eww.yuck` / `eww.scss` / `voiceless-overlay.conf`：pill 窗口与尺寸参数

本仓库只安装运行时依赖（`eww`、`python3`）和 Voiceless 本体。每台新桌面主机需要先克隆该仓库到
`~/.config/eww/`，否则快捷键无响应。

## 云端配置与本地模型

ASR 与文本整理的云端配置位于 `~/.config/voiceless/config.toml`（权限 `0600`，含 DashScope API
key，**不由本仓库管理**）。每台新桌面主机需要自行创建该文件，至少包含
`[asr]`、`[cloud]`、`[processing]` 三节。`voiceless doctor` 检查 `pw-record`、`wtype`、`wl-copy`
和数据目录是否就绪。

本地 sherpa-onnx 模型仅在使用本地后端时需要，当前云端模式下无需安装。若以后切回本地推理（`[asr] streaming_backend`
改回 `local`），再通过 Voiceless 模型管理器安装：

```bash
voiceless model install streaming-paraformer-bilingual-zh-en
voiceless model list
```

模型进入 `~/.local/share/voiceless`，不写入 Git 或 Nix store。本地后端需要 GPU 加速时，把
`voice-input.nix` 中的 `voiceless-cpu` 换回 `voiceless`（CUDA 版）即可。

## 验证

配置级检查：

```bash
niri validate
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.systemd.user.services.voiceless-web.Service.ExecStart --json
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.systemd.user.services.eww-voiceless-overlay.Service.ExecStart --json
```

运行时检查：

```bash
systemctl --user is-active eww-voiceless-overlay.service voiceless-web.service
```

本次切换已确认：

- Niri 接受两条 Scroll_Lock 绑定（`niri validate` 与热重载）。
- Apollo Home Manager 求值生成 Voiceless 与 eww 的 Nix store `ExecStart`。
- Voiceless flake 输入构建成功，服务集合不再包含 `type4me-linux`。

## 已知限制

- overlay 配置不在 nix-config 管理范围内，新主机需要手动克隆 `~/.config/eww`。
- `~/.config/voiceless/config.toml` 含 DashScope API
  key，同样不随仓库分发；缺少该文件时云端识别不可用。
- 识别依赖网络与 DashScope 服务可用性；离线场景需切回本地后端并安装模型。
- Voiceless 使用 GitHub flake 输入；更新应用前必须先推送 voiceless 仓库提交，再执行
  `nix flake lock --update-input voiceless`，以便系统配置继续可复现。
- Niri 没有按键松开绑定，所以只提供切换与取消，不提供按住说话。

## 回滚

从 `flake.nix` 移除 `voiceless` 输入，将 `voice-input.nix` 恢复为 Type4Me 版本（见 Git 历史），并把
`keybindings.kdl` 中两条 Scroll_Lock 绑定改回 Type4Me
D-Bus 调用。重新部署后，系统将回到 Type4Me 全局语音输入。

## 参考资料

- [Voiceless](https://github.com/Vitus213/voiceless)
- [Niri 键绑定](https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings)

## Fcitx5 桥接上屏

`home/linux/gui/base/voice-input.nix` 把 `voiceless-fcitx5-bridge` 加入 Fcitx5 addons。该模块在
`org.fcitx.Fcitx5` 的 `/voiceless` 上提供 `dev.voiceless.Fcitx5Bridge1.CommitString`，Voiceless 在
`inject.prefer = "fcitx5"`
时通过它把最终文本提交到当前焦点输入框，和输入法打字上屏同一路径；Wayland 与 XWayland（微信等 XIM 应用）都适用。调用失败（Fcitx5 未运行、没有焦点输入框）时按
`clipboard_fallback = true` 回退到剪贴板方式。

- 检查：`voiceless doctor` 中的 `fcitx5 bridge` 项，或
  `busctl --user call org.fcitx.Fcitx5 /voiceless dev.voiceless.Fcitx5Bridge1 Status`。
- 回滚：把 `inject.prefer` 改回 `"clipboard"`；如需彻底移除，删掉 `voice-input.nix` 中的
  `i18n.inputMethod.fcitx5.addons` 一段并 rebuild。

## 当前架构（2026-10-20 重构后）

- **识别**：`[asr] streaming_backend = "local-offline"`，默认模型 `qwen3-asr-1.7b-gguf`
  （transcribe.cpp + CUDA，约 2.5 GB 显存）。Silero
  VAD 按停顿切句，当前句每 0.5 秒在 GPU 上重算一次作为实时显示，松手后得到最终结果。
- **常驻 daemon**：`voiceless.service`（`voiceless daemon`）启动时把模型加载进显存；快捷键只调用
  `voiceless ctl toggle|start|stop|cancel`，或由 daemon 直接读 ScrollLock（`[hotkey] key`，需
  `input` 组）。
- **上屏**：`inject.prefer = "fcitx5"`，识别中的文字经桥接模块显示为输入框内的预编辑，最终文本由 fcitx5 提交；失败时回退剪贴板。
- **浮层**：`voiceless-overlay-eww.service` + `voiceless-overlay.service`，配置在
  `~/.config/eww-voiceless`。
- **文本清理**：`[text]` 去掉“呃”等语气词，热词按拼音纠错并同时用于识别偏置。
- **控制台**：浏览器打开 http://127.0.0.1:8790/（由
  daemon 提供）：实时状态与开始/停止、引擎与模型下载、词库（热词/替换/正则，带实时预览）、模式与提示词、快捷键录制与测试上屏、历史（重新识别、一键纠错）、诊断与回放基准。
- 排查：`voiceless doctor`、`voiceless ctl status`、`voiceless ctl watch`、`journalctl --user -u voiceless`。
