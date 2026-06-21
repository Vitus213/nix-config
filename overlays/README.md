# Overlays

这个目录存放 NixOS 和 nix-darwin 共享的 nixpkgs overlays。

## 结构

```text
overlays/
├── default.nix
└── fcitx5/
```

## 当前 overlay

- `default.nix`: overlays 入口，导入当前目录下的 overlay
- `fcitx5/`: 为 Rime 提供雾凇拼音 Rime Ice 数据，供 Linux 的 `fcitx5-rime` 和 macOS 的 Squirrel 使用

## 参考

- [Overlays - NixOS & Flakes Book](https://nixos-and-flakes.thiscute.world/nixpkgs/overlays)
