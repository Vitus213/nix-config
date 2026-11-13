# Overlays

这个目录存放 NixOS 和 nix-darwin 共享的 nixpkgs overlays。

## 结构

```text
overlays/
├── default.nix
├── ccusage/
├── croc/
├── fcitx5/
├── niri/
├── noctalia/
├── wechat/
└── wemeet/
```

## 当前 overlay

- `default.nix`: overlays 入口，导入当前目录下的 overlay
- `ccusage/`: 固定 ccusage `20.0.39` 官方 npm 静态二进制，替换 nixpkgs
  `20.0.17`（缺少 Codex/Claude 去重修复），供 agent-usage 统计
- `croc/`: 临时修正 `croc 10.4.5` GitHub source archive hash drift，保证系统 build 可通过
- `fcitx5/`: 为 Rime 提供雾凇拼音 Rime Ice 数据，供 Linux 的 `fcitx5-rime` 和 macOS 的 Squirrel 使用
- `niri/`: 为 Niri `26.04` 回移上游 PR #1791 的 ScreenCast SHM 回退，修复腾讯会议等客户端
  `no more input formats`；详见 `documents/tencent-meeting.md`
- `noctalia/`: 复用固定官方 Noctalia `5.5.0`
  包，只追加专用 PAM 与数字工作区状态两个 C++ 补丁；仅支持 x86_64-linux/aarch64-linux，详见
  `documents/noctalia-v5.md`。
- `wechat/`: 固定官方 Linux DEB
  `4.1.13.26`，局部回移上游依赖修补，使用原生 Wayland/text-input-v3；直接运行，不隔离家目录，详见
  `documents/linux-im-apps.md`。
- `wemeet/`: 统一腾讯会议 XWayland 启动入口，以本地 portal/PipeWire/EGL 采集库替换旧 hook，适配 xwayland-satellite 共享边框，并定制固定 x86-64 版本的原生配色；录制与功能验收边界见
  `documents/tencent-meeting.md`。

## 参考

- [Overlays - NixOS Wiki](https://wiki.nixos.org/wiki/Overlays)
