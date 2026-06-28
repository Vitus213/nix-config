# Fcitx5 输入法

这个目录存放 Linux 桌面使用的 Fcitx5 用户配置。

## 当前文件

- `profile`: 链接到 `~/.config/fcitx5/profile`
- `config`: 链接到 `~/.config/fcitx5/config`，固定 Fcitx5 全局快捷键
- `mozc-config1.db`: 链接到 `~/.config/mozc/config1.db`
- `classicui.conf`: Fcitx5 Classic UI 配置
- `default.custom.yaml`: Rime 用户补丁，固定小鹤双拼并调整 Rime 内部中/西文切换键

## 注意

`mozc-config1.db` 的主要改动是让字母、数字和标点默认使用半角。

Rime 当前只保留 `double_pinyin_flypy` 小鹤双拼方案。`Ctrl+Space`
由 Rime 处理，用于在小鹤双拼内切换中文状态和 Rime 西文状态
`Ａ`；Shift、CapsLock 和 Control 不参与输入法切换，其中 CapsLock 保留给 keyd 的 Esc/Ctrl 映射。

Fcitx5 的 Default 输入法组只保留 `rime`，避免日常在 `rime` 和英文键盘 `en`
之间轮转。Fcitx5 全局层清空 Shift 临时切换键，只保留 `Ctrl+Alt+Space` 作为救援激活/关闭快捷键。

详细使用、验证和回滚方式见 `documents/fcitx5-rime-input-method.md`。

参考: <https://github.com/google/mozc/blob/2.30.5544.102/docs/configurations.md>
