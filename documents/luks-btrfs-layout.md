# LUKS + Btrfs 分区示例

[全新 NixOS 部署流程](./fresh-nixos-preservation-deploy.md)
默认使用 ext4。需要整盘加密或 Btrfs子卷（快照、压缩）时，用本文的步骤替换那份文档的“3. 分区、格式化、挂载”一节，其余步骤不变。

当前仓库没有主机在用这套布局（`apollo`
是 ext4），本文仅作参考。无论用哪种布局，都必须保留一个最终挂载到 `/persistent`
的持久化位置，preservation 依赖它。

## 分区

下面命令只作为示例，实际设备名必须先用 `lsblk` 确认。

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 2MB 629MB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 630MB 100%
```

## 加密 root 分区

```bash
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --hash sha512 --iter-time 5000 --key-size 256 --pbkdf argon2id --use-random --verify-passphrase /dev/nvme0n1p2
cryptsetup luksOpen /dev/nvme0n1p2 crypted-nixos
```

## 创建 Btrfs 子卷

```bash
mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
mkfs.btrfs -L crypted-nixos /dev/mapper/crypted-nixos

mount /dev/mapper/crypted-nixos /mnt
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@persistent
btrfs subvolume create /mnt/@snapshots
umount /mnt
```

如果启用了 Guix（`modules/nixos/desktop/guix.nix`），再加一个 `@guix` 子卷挂到 `/gnu`。

## 挂载子卷

```bash
mkdir -p /mnt/{nix,tmp,swap,persistent,snapshots,boot}
mount -o compress-force=zstd:1,noatime,subvol=@nix /dev/mapper/crypted-nixos /mnt/nix
mount -o compress-force=zstd:1,subvol=@tmp /dev/mapper/crypted-nixos /mnt/tmp
mount -o subvol=@swap /dev/mapper/crypted-nixos /mnt/swap
mount -o compress-force=zstd:1,noatime,subvol=@persistent /dev/mapper/crypted-nixos /mnt/persistent
mount -o compress-force=zstd:1,noatime,subvol=@snapshots /dev/mapper/crypted-nixos /mnt/snapshots
mount /dev/nvme0n1p1 /mnt/boot
```

## swapfile

大小按内存调整：

```bash
btrfs filesystem mkswapfile --size 16g --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile
```

## 修改 LUKS2 密码

```bash
sudo cryptsetup --verbose open --test-passphrase /path/to/dev/
sudo cryptsetup luksChangeKey /path/to/dev/
sudo cryptsetup --verbose open --test-passphrase /path/to/dev/
```

快照与备份见 [btrbk 配置状态](./btrbk.md)。
