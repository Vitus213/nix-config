# Home Manager 配置

这个目录存放所有用户级配置，按共享层和平台层拆分。

## 目录结构

```text
home/
├── base/      # Linux 和 macOS 共享的 home-manager 配置
├── linux/     # Linux 专用配置
└── darwin/    # macOS 专用配置
```

## 分层说明

- `base/`: shell、git、编辑器、终端工具、跨平台 GUI 配置
- `linux/`: Linux 桌面、niri、Noctalia Shell、Fcitx5、Wayland 相关配置
- `darwin/`: macOS、AeroSpace、Squirrel、代理和终端配置

## 使用原则

- 用户级 dotfiles 优先放在 `home/`
- 系统服务、内核、用户组和硬件配置放在 `modules/` 或 `hosts/`
- 与单个主机强绑定的 home-manager 配置放在 `hosts/<host>/home.nix`
- secrets 通过 agenix 暴露路径，不要把明文写进 home-manager 文件
