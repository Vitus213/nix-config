# Overlays

这个目录存放 NixOS 和 nix-darwin 共享的 nixpkgs overlays。

## 结构

```text
overlays/
├── default.nix
├── delta/
├── fcitx5/
├── niri/
├── noctalia/
├── wechat/
├── tern/
└── wemeet/
```

## 当前 overlay

- `default.nix`: overlays 入口，导入当前目录下的 overlay
- `fcitx5/`: 仅让 `fcitx5-rime` 使用上游 `pkgs.rime-ice`，不再覆盖全局
  `rime-data`；macOS 直接消费同一上游包。
- `niri/`: 为 Niri `26.04` 回移上游 PR #1791 的 ScreenCast SHM 回退，修复腾讯会议等客户端
  `no more input formats`；详见 `documents/tencent-meeting.md`
- `noctalia/`: 复用固定官方 Noctalia 包，使用正式 PAM helper 和 `pam_service=noctalia-lock`
  构建选项，只保留工作区状态 C++ 补丁；详见 `documents/noctalia-v5.md`。
- `wechat/`: 复用上游 Linux DEB 配方与 WMPF 修复，只强制原生 Wayland、text-input-v3 和
  `NIXOS_OZONE_WL=1`；详见 `documents/linux-im-apps.md`。
- `delta/`、`tern/`: 适配上游输入提供的包名与平台入口，不复制打包配方。
- `wemeet/`: 统一腾讯会议 XWayland 启动入口，以本地 portal/PipeWire/EGL 采集库替换旧 hook，适配 xwayland-satellite 共享边框，并定制固定 x86-64 版本的原生配色；录制与功能验收边界见
  `documents/tencent-meeting.md`。

ccusage、croc 直接使用更新后的 nixpkgs；未被本仓库消费的 Magpie
overlay 已退役，J1900 网关和 OMP 客户端配置不变。

## 参考

- [Overlays - NixOS Wiki](https://wiki.nixos.org/wiki/Overlays)
