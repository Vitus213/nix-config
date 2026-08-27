# Linux 图形桌面配置

这个目录存放由 Home Manager 管理的 Linux 桌面配置。

## 主要模块

- `niri/`: Niri compositor 配置、快捷键、窗口规则和自启动
- `base/`: 桌面通用应用和服务

`base/` 中包含:

- Noctalia Shell
- Fcitx5 输入法
- GTK 和 XDG 配置
- Wayland 桌面工具
- Type4Me 语音输入
- 媒体、创作、笔记和开发工具
- 游戏相关工具

## 为什么桌面配置主要放 Home Manager

桌面配置多数位于 `~/.config`，并且很多服务是用户级 systemd
service，例如 noctalia-shell、fcitx5、hypridle。

用 Home Manager 管理这些内容更容易控制用户服务的启动顺序，也更方便在非 NixOS Linux 环境复用。
