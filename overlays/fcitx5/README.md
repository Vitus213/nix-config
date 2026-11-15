# Rime Ice 数据 overlay

这个 overlay 仅覆盖 `fcitx5-rime.rimeDataPkgs`，选择 nixpkgs 的
[`rime-ice`](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/pkgs/by-name/ri/rime-ice/package.nix)。不再自打包数据、不覆盖全局
`rime-data` 或 `rime-ice`，也不提供 Darwin 别名。

## Linux

`~/.config/fcitx5/profile` 链接到
[home/linux/gui/base/fcitx5/profile](../../home/linux/gui/base/fcitx5/profile)，默认启用 Rime。

## macOS

macOS 直接从 `pkgs.rime-ice` 链接所需数据到 `~/Library/Rime/`。具体见
[home/darwin/rime-squirrel.nix](../../home/darwin/rime-squirrel.nix)。

## 输入方案

当前数据源默认包含:

- `rime_ice`: 全拼
- `double_pinyin_flypy`: 小鹤双拼

上游把建议配置的 `default.yaml` 命名为 `rime_ice_suggestion.yaml`，Linux 的 `default.custom.yaml`
显式包含 `patch.__include: rime_ice_suggestion:/`，随后保留本地小鹤双拼和快捷键补丁。

## 参考

- [Fcitx5 - Arch Wiki](https://wiki.archlinux.org/title/Fcitx5)
- [Fcitx5 官方 Wiki](https://fcitx-im.org/wiki/Fcitx_5/zh-cn)
