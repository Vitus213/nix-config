# Athena 主机

`athena` 是规划中的第二台 NixOS 桌面，配置入口在 `hosts/olympians-athena/default.nix`。

相关文档:

- [nixos-installer](../../nixos-installer/README.md)
- [全新 NixOS + preservation 部署流程](../../documents/fresh-nixos-preservation-deploy.md)

## 待办

1. 安装 DCGM-Exporter，用于监控 GPU 状态。

## 磁盘和挂载示例

下面内容是历史环境中的 `df -Th` 和 `lsblk`
输出，用来记录当时的 Btrfs、LUKS 和 preservation 挂载形态。迁移到新机器时不要直接照抄设备名。

```bash
Filesystem                Type      Size  Used Avail Use% Mounted on
devtmpfs                  devtmpfs  1.6G     0  1.6G   0% /dev
tmpfs                     tmpfs      16G  8.0K   16G   1% /dev/shm
tmpfs                     tmpfs     7.8G  7.9M  7.8G   1% /run
tmpfs                     tmpfs      16G  1.1M   16G   1% /run/wrappers
tmpfs                     tmpfs      16G   87M   16G   1% /
/dev/mapper/crypted-nixos btrfs     1.9T  630G  1.3T  34% /persistent
/dev/mapper/crypted-nixos btrfs     1.9T  630G  1.3T  34% /nix
/dev/mapper/crypted-nixos btrfs     1.9T  630G  1.3T  34% /snapshots
/dev/mapper/crypted-nixos btrfs     1.9T  630G  1.3T  34% /swap
/dev/nvme0n1p1            vfat      597M  108M  490M  19% /boot
/dev/mapper/crypted-nixos btrfs     1.9T  630G  1.3T  34% /tmp
```

```bash
NAME              MAJ:MIN RM  SIZE RO TYPE  MOUNTPOINTS
zram0             253:0    0 15.6G  0 disk  [SWAP]
nvme0n1           259:0    0  1.8T  0 disk
├─nvme0n1p1       259:2    0  598M  0 part  /boot
└─nvme0n1p2       259:3    0  1.8T  0 part
  └─crypted-nixos 254:0    0  1.8T  0 crypt /tmp
                                            /swap
                                            /snapshots
                                            /nix
                                            /persistent
```
