# Apollo 主机

`apollo` 是当前主力 NixOS 桌面，配置入口在 `hosts/olympians-apollo/default.nix`。

相关文档:

- [nixos-installer](../../nixos-installer/README.md)
- [全新 NixOS + preservation 部署流程](../../documents/fresh-nixos-preservation-deploy.md)

## 待办

1. 安装 DCGM-Exporter，用于监控 NVIDIA GPU 状态。

## 当前硬件

- CPU: AMD Ryzen 5 5600
- GPU: NVIDIA GeForce RTX 3070 LHR
- 网络: NetworkManager + DHCP

## 磁盘和持久化

- `/`: `/dev/disk/by-uuid/83ef9088-b0fc-49f1-bf67-51f8d8bfc2cb`，ext4
- `/boot`: `/dev/disk/by-uuid/C799-4063`，vfat
- `/home/vitus/nix-config`: 从 `/persistent/home/vitus/nix-config` bind mount
- SSH host keys 以单个文件形式持久化到 `/persistent/etc/ssh`，没有整体挂载 `/etc/ssh`
- agenix 在 preservation 场景下使用 `/home/vitus/.ssh/id_ed25519`
