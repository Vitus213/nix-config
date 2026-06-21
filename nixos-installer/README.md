# NixOS 安装器配置

这个目录保留一个较小的安装用 flake，用来在 ISO 环境里快速测试和安装 `apollo` 的基础系统。

> 当前更推荐阅读
> [documents/fresh-nixos-preservation-deploy.md](../documents/fresh-nixos-preservation-deploy.md)。那份文档记录了现在全新 NixOS 机器启用 preservation、使用用户
> `~/.ssh/id_ed25519` 做 agenix identity 的完整流程。

## 为什么保留这个目录

主仓库 flake 较重，第一次安装时容易被硬件配置、secrets、桌面模块和缓存问题同时卡住。这个目录的作用是:

1. 在 ISO 里快速验证新的 `hardware-configuration.nix`
2. 测试文件系统、LUKS、Btrfs、preservation、Secure Boot 等底层改动
3. 在部署主 flake 前得到一个能启动的最小系统

## 推荐流程

1. 从官方 NixOS ISO 启动
2. 分区、格式化、挂载到 `/mnt`
3. 运行 `nixos-generate-config --root /mnt`
4. 把生成的硬件配置迁移到目标主机目录
5. 使用本目录 flake 或主 flake 安装
6. 第一次重启前，把 `machine-id`、SSH host key 等需要持久化的文件放入 `/persistent`
7. 第一次启动后生成 `~/.ssh/id_ed25519`
8. 为 private secrets 仓库 rekey
9. 回到主 flake 执行正式 `nixos-rebuild switch`

## LUKS + Btrfs 示例

下面命令只作为示例。实际设备名必须先用 `lsblk` 确认。

创建分区:

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 2MB 629MB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 630MB 100%
```

加密 root 分区:

```bash
cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 --hash sha512 --iter-time 5000 --key-size 256 --pbkdf argon2id --use-random --verify-passphrase /dev/nvme0n1p2
cryptsetup luksOpen /dev/nvme0n1p2 crypted-nixos
```

创建 Btrfs 子卷:

```bash
mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
mkfs.btrfs -L crypted-nixos /dev/mapper/crypted-nixos

mount /dev/mapper/crypted-nixos /mnt
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@guix
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@persistent
btrfs subvolume create /mnt/@snapshots
umount /mnt
```

挂载子卷:

```bash
mkdir -p /mnt/{nix,gnu,tmp,swap,persistent,snapshots,boot}
mount -o compress-force=zstd:1,noatime,subvol=@nix /dev/mapper/crypted-nixos /mnt/nix
mount -o compress-force=zstd:1,noatime,subvol=@guix /dev/mapper/crypted-nixos /mnt/gnu
mount -o compress-force=zstd:1,subvol=@tmp /dev/mapper/crypted-nixos /mnt/tmp
mount -o subvol=@swap /dev/mapper/crypted-nixos /mnt/swap
mount -o compress-force=zstd:1,noatime,subvol=@persistent /dev/mapper/crypted-nixos /mnt/persistent
mount -o compress-force=zstd:1,noatime,subvol=@snapshots /dev/mapper/crypted-nixos /mnt/snapshots
mount /dev/nvme0n1p1 /mnt/boot
```

创建 swapfile:

```bash
btrfs filesystem mkswapfile --size 96g --uuid clear /mnt/swap/swapfile
swapon /mnt/swap/swapfile
```

## 安装

准备工具和仓库:

```bash
nix-shell -p git vim just nushell
git clone https://github.com/Vitus213/nix-config.git /tmp/nix-config
```

生成硬件配置:

```bash
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
  /tmp/nix-config/hosts/olympians-apollo/hardware-configuration.nix
```

安装:

```bash
cd /tmp/nix-config
nixos-install --root /mnt --flake .#apollo --no-root-password --show-trace --verbose
```

如果需要指定缓存镜像:

```bash
nixos-install --root /mnt --flake .#apollo --no-root-password --show-trace --verbose \
  --option substituters "https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/"
```

## 第一次重启前

preservation 不会自动把已有文件搬进 `/persistent`。安装完成后先处理关键状态:

```bash
mkdir -p /mnt/persistent/etc/ssh

if [ -f /mnt/etc/machine-id ]; then
  mkdir -p /mnt/persistent/etc
  mv /mnt/etc/machine-id /mnt/persistent/etc/
fi

if ls /mnt/etc/ssh/ssh_host_* >/dev/null 2>&1; then
  mv /mnt/etc/ssh/ssh_host_* /mnt/persistent/etc/ssh/
fi
```

然后卸载并重启:

```bash
sync
swapoff /mnt/swap/swapfile
umount -R /mnt
cryptsetup close /dev/mapper/crypted-nixos
reboot
```

## 切换到主 flake

第一次启动后，按当前流程生成用户 key，并为 private secrets rekey:

```bash
ssh-keygen -t ed25519 -a 256 -C "vitus@$(hostname)-agenix" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

完成 rekey 后:

```bash
cd ~/nix-config
nix flake update mysecrets
sudo nixos-rebuild switch --flake .#$(hostname) --show-trace --verbose
```

## 修改 LUKS2 密码

```bash
sudo cryptsetup --verbose open --test-passphrase /path/to/dev/
sudo cryptsetup luksChangeKey /path/to/dev/
sudo cryptsetup --verbose open --test-passphrase /path/to/dev/
```
