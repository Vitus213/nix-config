# Linux 应用沙箱

`hardening/` 当前仅保留 Telegram Desktop 的 Nixpak 包装。Telegram 仍使用 Bubblewrap、D-Bus
proxy 和桌面 portal；未启用的 AppArmor 和 hardened
profile 模板已删除，QQ 包装及导出也已移除。QQ 当前暂停安装，见
[Linux 微信、QQ 与飞书](../documents/linux-im-apps.md)。

## 当前结构与行为

```text
hardening/
├── README.md
└── nixpaks/
    ├── default.nix
    ├── telegram-desktop.nix
    └── modules/
        ├── common.nix
        ├── gui-base.nix
        └── network.nix
```

`nixpaks/default.nix` 导出 `pkgs.nixpaks.telegram-desktop`，由 Home Manager 安装。
`telegram-desktop.nix`
保留联网、Wayland、PipeWire、文档/下载/媒体目录和现有通知、托盘、portal 权限。 `gui-base.nix`
使用 NixOS GPU provider 绑定宿主 `/run/opengl-driver`，并保留已有 NVIDIA 设备访问。 `~/.var`
中的应用数据继续由 Apollo 的 preservation 映射保留。

Nixpak 不要求安装 Flatpak 服务。主机已没有 Flatpak 应用，系统 Flatpak 服务与对应持久化声明已经移除；Telegram 继续使用 Nixpak 的
`flatpak.appId` 作为应用身份与数据目录名称。

## 上游已经提供的行为

锁定 Nixpak 为 `be97295fa81fe743b9753449143dd4931e51d63c`：

- [`bubblewrap.nix`](https://github.com/nixpak/nixpak/blob/be97295fa81fe743b9753449143dd4931e51d63c/modules/bubblewrap.nix)
  在联网且未启用 pasta 时自动只读绑定 `/etc/resolv.conf` 和
  `/etc/hosts`，本地不再重复添加 resolv.conf。
- [`launch.nix`](https://github.com/nixpak/nixpak/blob/be97295fa81fe743b9753449143dd4931e51d63c/modules/launch.nix)
  为 D-Bus proxy 自动添加 `--filter`，本地只保留已有其他参数。
- [`gpu.nix`](https://github.com/nixpak/nixpak/blob/be97295fa81fe743b9753449143dd4931e51d63c/modules/gpu.nix)
  仅在 `provider = "bundle"` 时使用 `bundlePackage`；当前 provider 为 `nixos`，已删除无效的 Mesa
  bundle 设置。

## 清理边界与回滚

本轮删除未启用的系统加固模板、暂停使用的 QQ 包装、无人消费的
`safeBind`，不增加新的权限或安全方案，也不删除应用数据。沙箱权限仍以现有 Telegram 配置为准。

恢复 QQ 时需要重新加入包装和包导出，再由 Home
Manager 声明安装；恢复系统加固时需加入真实主机导入与可用策略。仅恢复一份从未导入的模板不会产生系统行为。历史应用数据保留，回滚不需要清空
`~/.var`。

本轮未运行构建或启动 Telegram。统一验证应确认 Telegram 包仍可求值，并在正常部署后确认联网、图形、通知和 portal 行为。
