# Rime Ice 数据 overlay

这个 overlay 提供 [雾凇拼音 Rime Ice](https://github.com/iDvel/rime-ice) 数据。

## 使用场景

- Linux: `fcitx5-rime`
- macOS: Squirrel

## Linux

`~/.config/fcitx5/profile` 链接到
[home/linux/gui/base/fcitx5/profile](../../home/linux/gui/base/fcitx5/profile)，默认启用 Rime。

## macOS

`~/Library/Rime/` 由 Home Manager 链接到这份 Rime 数据。具体见
[home/darwin/rime-squirrel.nix](../../home/darwin/rime-squirrel.nix)。

## 输入方案

当前数据源默认包含:

- `rime_ice`: 全拼
- `double_pinyin_flypy`: 小鹤双拼

## 参考

- [Fcitx5 - Arch Wiki](https://wiki.archlinux.org/title/Fcitx5)
- [Fcitx5 官方 Wiki](https://fcitx-im.org/wiki/Fcitx_5/zh-cn)
