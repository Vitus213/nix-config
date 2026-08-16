# Linux 语音输入

本文记录 `apollo` 的 NixOS + Niri Wayland 语音输入方案。配置位于 Linux GUI Home
Manager 基础模块，也会进入使用该模块的同类桌面会话。

## 当前结论

Syllune 是 Niri 唯一的全局语音输入入口。

- Syllune flake 输入：`github:Vitus213/syllune`，由 `flake.lock` 固定到已验证提交
- Home Manager 配置：`home/linux/gui/base/voice-input.nix`
- Niri 快捷键：`home/linux/gui/niri/conf/keybindings.kdl`
- Syllune 版本：`0.1.0`
- Niri 版本：`26.04`

Syllune 是 Rust 实现的本地实时转写工具，使用 sherpa-onnx 的 `streaming-paraformer-bilingual-zh-en`
模型，最终文本优先通过 `wtype` 注入当前 Wayland 客户端，失败时回退到
`wl-copy`；录音、注入工具由 Syllune 包的 wrapper 自带，无需另行安装。

## 当前行为

Home Manager 安装 Syllune、`eww`、`python3`，并声明两个随 Wayland 会话启动的用户服务：

- `eww-syllune-overlay.service`：`eww daemon`，承载 overlay pill 窗口
- `syllune-web.service`：`syllune history serve`，历史记录 Web 控制台，默认监听 `127.0.0.1:8790`

Niri 快捷键不直接调用 Syllune，而是调用 overlay 触发脚本：

- `Scroll Lock`：空闲时启动 `quick` 模式；识别中则停止会话并注入最终文本
- `Ctrl + Scroll Lock`：空闲时启动 `prompt-optimize`（LLM 整理）模式；识别中不重复启动

两个绑定都设置
`repeat=false`。Niri 当前不提供按键松开动作，因此不配置按住说话；切换模式是该合成器上可确定实现的行为。

触发脚本拉起 Python overlay pump：pump 运行
`syllune stream --json`，把实时识别文本经 FIFO 推给 eww 的
`deflisten`，在屏幕底部中央显示一个 layer-shell pill，会话结束后自动关闭。

## 仓库外依赖

overlay 的配置与脚本位于 `~/.config/eww/`（独立 Git 仓库 `Vitus213` 名下），**不由本仓库管理**：

- `syllune-overlay-toggle`：Niri 快捷键的入口脚本
- `syllune-overlay.py`：`syllune stream` 与 eww 之间的 pump
- `syllune-overlay-listen.sh`：eww `deflisten` feeder
- `eww.yuck` / `eww.scss` / `syllune-overlay.conf`：pill 窗口与尺寸参数

本仓库只安装运行时依赖（`eww`、`python3`）和 Syllune 本体。每台新桌面主机需要先克隆该仓库到
`~/.config/eww/`，否则快捷键无响应。

## 模型

模型由 Syllune 自己的模型管理器安装和校验：

```bash
syllune model list
syllune model install streaming-paraformer-bilingual-zh-en
syllune doctor
```

模型进入 `~/.local/share/syllune`，不写入 Git 或 Nix store。`syllune doctor` 检查
`pw-record`、`wtype`、`wl-copy` 和数据目录是否就绪。

## 验证

配置级检查：

```bash
niri validate
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.systemd.user.services.syllune-web.Service.ExecStart --json
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.systemd.user.services.eww-syllune-overlay.Service.ExecStart --json
```

运行时检查：

```bash
systemctl --user is-active eww-syllune-overlay.service syllune-web.service
```

本次切换已确认：

- Niri 接受两条 Scroll_Lock 绑定（`niri validate` 与热重载）。
- Apollo Home Manager 求值生成 Syllune 与 eww 的 Nix store `ExecStart`。
- Syllune flake 输入构建成功，服务集合不再包含 `type4me-linux`。

## 已知限制

- overlay 配置不在 nix-config 管理范围内，新主机需要手动克隆 `~/.config/eww`。
- Syllune 使用 GitHub flake 输入；更新应用前必须先推送 syllune 仓库提交，再执行
  `nix flake lock --update-input syllune`，以便系统配置继续可复现。
- Niri 没有按键松开绑定，所以只提供切换与取消，不提供按住说话。
- 模型需要单独安装；缺少模型时服务仍可启动，但识别不能完成。

## 回滚

从 `flake.nix` 移除 `syllune` 输入，将 `voice-input.nix` 恢复为 Type4Me 版本（见 Git 历史），并把
`keybindings.kdl` 中两条 Scroll_Lock 绑定改回 Type4Me
D-Bus 调用。重新部署后，系统将回到 Type4Me 全局语音输入。

## 参考资料

- [Syllune](https://github.com/Vitus213/syllune)
- [Niri 键绑定](https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings)
