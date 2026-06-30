# Generic 主机

`generic` 是不依赖个人 secrets 和 preservation 的通用 NixOS 桌面 host。

相关文档:

- [通用 NixOS 桌面 Host](../../documents/generic-nixos-host.md)

## 当前硬件

- 复制自 `apollo`，部署到新机器前应替换 `hardware-configuration.nix`
- 网络: NetworkManager + DHCP

## 当前裁剪

- 不导入 `secrets/nixos.nix`
- 不启用 `modules.secrets.desktop.enable`
- 不导入 `preservation.nix`
- 不加载 `/etc/agenix/*` 下的个人 secret
