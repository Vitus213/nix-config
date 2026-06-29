# Linux Voxtype 语音输入

本文记录当前 Linux 桌面语音输入方案。配置面向 `apollo` 的 NixOS + Niri Wayland 环境，也会随 Linux GUI Home Manager 基础模块进入同类桌面会话。

## 当前结论

当前使用 [Voxtype](https://github.com/peteonrails/voxtype) 作为全局语音输入入口。

- 配置入口：`home/linux/gui/base/voice-input.nix`
- Niri 快捷键入口：`home/linux/gui/niri/conf/keybindings.kdl`
- Voxtype 版本：`0.7.2`
- 输出方式：优先通过 `wtype` 向当前光标位置输入文本，失败时回退到 `wl-copy` 剪贴板
- 识别模型：`small`
- 识别语言：`zh`
- 内置热键：关闭，由 Niri 快捷键调用 `voxtype record`
- OSD：关闭，因为当前 nixpkgs 中没有打包 `voxtype-osd-native` 或 `voxtype-osd-gtk4`

## 为什么选 Voxtype

已对比的候选方案包括 Voxtype、whisrs、nerd-dictation、Speech Note 和 whisper-overlay。

Voxtype 更适合当前环境：

- 原生面向 Wayland，官方文档明确支持 Niri、Hyprland、Sway、River、GNOME 和 KDE。
- 可通过 compositor 快捷键控制录音，不需要依赖 evdev 全局热键，也就不要求把用户加入 `input` 组。
- 输出链支持 `wtype`，当前 Niri 会话已暴露 `zwp_virtual_keyboard_manager_v1`，实测 `wtype` 可用。
- 支持 CJK 文本输入，并带剪贴板回退。
- nixpkgs 已提供 `pkgs.voxtype` 和 `pkgs.voxtype-vulkan`，不需要先引入额外 flake。

当前先集成 CPU 版 `pkgs.voxtype`。`pkgs.voxtype-vulkan` 在 RTX 3070 上可以正常识别，但短音频测试里 Vulkan 初始化开销明显，首版先保留更稳的 CPU 路径。需要长音频或更大模型时，再单独评估是否切到 `pkgs.voxtype-vulkan`。

## 当前行为

Home Manager 会安装：

- `voxtype`
- `wtype`
- `wl-clipboard`
- `libnotify`
- `playerctl`

并写入 `~/.config/voxtype/config.toml`。

用户级 systemd 服务 `voxtype.service` 会随 Wayland 图形会话启动：

```bash
systemctl --user status voxtype.service
```

Niri 快捷键：

- `Mod + Shift + Space`：开始或停止录音
- `Mod + Ctrl + Shift + Space`：取消当前录音或转写

转写完成后，文本会优先直接输入到当前焦点窗口；如果虚拟键盘输入失败，Voxtype 会把文本写入剪贴板。

## 首次使用

模型文件不放进 Git 或 Nix store。首次使用前执行一次：

```bash
tmp_config="$(mktemp -d)"
XDG_CONFIG_HOME="$tmp_config" voxtype setup --download --model small --no-post-install
rm -rf "$tmp_config"
```

模型会下载到：

```text
~/.local/share/voxtype/models/
```

这里临时覆盖 `XDG_CONFIG_HOME`，是为了避免 `voxtype setup` 尝试写入由 Home Manager 管理的
`~/.config/voxtype/config.toml`。不要直接用 `voxtype setup --download ...` 覆盖当前配置。

配置变更部署后，重启用户服务：

```bash
systemctl --user restart voxtype.service
```

或者重新登录一次图形会话。

## 验证

低风险检查：

```bash
voxtype --version
voxtype setup check
systemctl --user status voxtype.service
```

单文件转写测试：

```bash
voxtype transcribe /path/to/sample.wav
```

本次集成前已验证：

- `pkgs.voxtype` 为 `0.7.2`。
- `voxtype setup check` 能识别当前 Wayland、`wtype` 和 `wl-copy`。
- 官方 JFK wav 样本可用 CPU 版成功转写。
- `pkgs.voxtype-vulkan` 能检测到 NVIDIA RTX 3070 并成功转写同一样本。
- `[osd].enabled = false` 在本地 daemon 测试中生效，服务可保持运行且不会调用缺失的 OSD 前端。

## 已知限制

- 首次使用必须手动下载 Whisper 模型；Nix 构建和 Home Manager 激活阶段不会访问网络下载模型。
- 当前配置不使用 evdev 热键，因此不需要 `input` 用户组；如果以后启用 Voxtype 内置热键或 modifier release guard，再重新评估权限。
- OSD 暂时关闭。要启用 OSD，需要先确认 nixpkgs 或上游 flake 中的 OSD 前端如何进入用户环境。
- `language = "zh"` 更偏向中文输入。长期需要大量中英混合时，可以评估切换为 `language = "auto"`。

## 回滚

删除或禁用 `home/linux/gui/base/voice-input.nix`，并移除 `home/linux/gui/niri/conf/keybindings.kdl` 中的 Voxtype 快捷键，然后重新部署 Home Manager 配置。

保留或删除模型目录不影响系统配置：

```bash
rm -rf ~/.local/share/voxtype
```

## 参考资料

- [Voxtype](https://github.com/peteonrails/voxtype)
- [Voxtype INSTALL.md](https://github.com/peteonrails/voxtype/blob/main/docs/INSTALL.md)
- [Voxtype CONFIGURATION.md](https://github.com/peteonrails/voxtype/blob/main/docs/CONFIGURATION.md)
- [wtype](https://github.com/atx/wtype)
- [Niri 配置文档](https://yalter.github.io/niri/Configuration:-Introduction)
