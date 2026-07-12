# Overlays

这个目录存放 NixOS 和 nix-darwin 共享的 nixpkgs overlays。

## 结构

```text
overlays/
├── default.nix
├── croc/
├── fcitx5/
└── stably-orca/
```

## 当前 overlay

- `default.nix`: overlays 入口，导入当前目录下的 overlay
- `croc/`: 临时修正 `croc 10.4.5` GitHub source archive hash drift，保证系统 build 可通过
- `fcitx5/`: 为 Rime 提供雾凇拼音 Rime Ice 数据，供 Linux 的 `fcitx5-rime` 和 macOS 的 Squirrel 使用
- `stably-orca/`: 固定 StablyAI Orca `1.4.137` 官方 Linux AppImage，并以 `pkgs.stably-orca`
  暴露，避免与 nixpkgs 的 GNOME `pkgs.orca` 冲突

## 参考

- [Overlays - NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/nixpkgs/overlays)
