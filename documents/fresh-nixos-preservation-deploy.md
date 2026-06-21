# 全新 NixOS 机器部署本仓库并启用 preservation

这份文档记录的是当前仓库的实际部署流程，目标是在一台全新的 NixOS 机器上套用本仓库里的 desktop 配置，并且启用
`preservation`。它不是通用 NixOS 教程。

当前关键约束:

- 默认用户名来自 `vars/default.nix`，当前是 `vitus`
- desktop 主机配置参考 `hosts/olympians-apollo/` 或 `hosts/olympians-athena/`
- preservation 配置在对应主机的 `preservation.nix`
- agenix 的 NixOS 配置在 `secrets/nixos.nix`
- preservation 开启时，agenix 解密 identity 使用 `/home/vitus/.ssh/id_ed25519`
- `/home/vitus/.ssh` 已经在 preservation 用户目录列表里，重启后应该保留

## 1. 先理解部署顺序

全新机器最容易踩坑的地方不是 Nix 语法，而是启动顺序:

1. 先用 ISO 分区、格式化、挂载目标系统
2. 生成本机 `hardware-configuration.nix`
3. 先让系统能安装并启动
4. 第一次启动后生成 `/home/vitus/.ssh/id_ed25519`
5. 用这把 key 的 public key 去 private secrets 仓库 rekey
6. 更新本仓库的 `mysecrets` input
7. 再执行正式 `nixos-rebuild switch`

不要跳过第 4 到第 6 步。否则 agenix 会解不开 secrets，后续会出现一串看起来像 `/etc/agenix` 或
`/run/agenix.d` 的错误，但根因其实是 age 解密失败。

## 2. 在 ISO 里准备环境

从官方 NixOS ISO 启动后，先进一个带常用工具的 shell:

```bash
nix-shell -p git vim just nushell
```

确认目标磁盘。下面示例假设磁盘是 `/dev/nvme0n1`，实际机器必须按 `lsblk` 结果替换。

```bash
lsblk
```

## 3. 分区、格式化、挂载

当前仓库的 preservation 方案需要一个持久化挂载点 `/persistent`。最简单的布局是:

- `/boot`: EFI system partition，vfat
- `/`: root 文件系统
- `/persistent`: 持久化数据目录

如果使用一个普通 ext4 root 分区，可以在安装前先创建 `/mnt/persistent`
目录；如果使用 btrfs，建议单独建 `@persistent` subvolume 并挂载到 `/mnt/persistent`。

示例，创建 ESP 和 root 分区:

```bash
parted /dev/nvme0n1 -- mklabel gpt
parted /dev/nvme0n1 -- mkpart ESP fat32 2MB 629MB
parted /dev/nvme0n1 -- set 1 esp on
parted /dev/nvme0n1 -- mkpart primary 630MB 100%
```

示例，使用 ext4:

```bash
mkfs.fat -F 32 -n ESP /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p2

mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot /mnt/persistent
mount /dev/disk/by-label/ESP /mnt/boot
```

如果你要用 LUKS 或 btrfs subvolume，可以参考 `nixos-installer/README.md`，但要保留一个最终挂载到
`/persistent` 的持久化位置。

## 4. 生成并迁移硬件配置

生成当前机器的硬件配置:

```bash
nixos-generate-config --root /mnt
```

把仓库 clone 到临时目录，再把生成的硬件配置拷贝进仓库对应主机目录。不要直接 clone 到
`/mnt/etc/nixos`，因为 `nixos-generate-config` 已经在那个目录里放了临时配置。

```bash
git clone https://github.com/Vitus213/nix-config.git /tmp/nix-config
cp /mnt/etc/nixos/hardware-configuration.nix \
  /tmp/nix-config/hosts/olympians-apollo/hardware-configuration.nix
```

然后检查这些项是否符合当前机器:

- `boot.initrd.availableKernelModules`
- `boot.kernelModules`
- `fileSystems."/"`.
- `fileSystems."/boot"`.
- `swapDevices`
- CPU 微码，例如 `hardware.cpu.amd.updateMicrocode`
- 是否需要 NVIDIA 配置

如果是新增主机，不要直接覆盖 `apollo`。应该复制一个类似主机目录，改:

- `hosts/<new-host>/default.nix`
- `hosts/<new-host>/hardware-configuration.nix`
- `hosts/<new-host>/preservation.nix`
- `outputs/x86_64-linux/src/<new-host>.nix`
- `vars/networking.nix`，如果需要固定网络信息

如果这台新机器还没有任何能访问 private `mysecrets` 的 SSH key，第一次安装可以先临时关掉 desktop
secrets。以 `apollo` 为例，在 `/tmp/nix-config/outputs/x86_64-linux/src/olympians-apollo.nix`
里临时改成:

```nix
modules.secrets.desktop.enable = false;
```

这只是 bootstrap 用的临时改动。完成 `~/.ssh/id_ed25519` 生成、private secrets rekey 和
`nix flake update mysecrets` 后，必须改回:

```nix
modules.secrets.desktop.enable = true;
```

## 5. 确认 preservation 配置

主机配置需要导入 preservation:

```nix
imports = [
  ./preservation.nix
];
```

并且 `preservation.nix` 里需要启用:

```nix
preservation.enable = true;
modules.secrets.preservation.enable = true;
boot.initrd.systemd.enable = true;
```

`modules.secrets.preservation.enable = true` 很关键。它会让 `secrets/nixos.nix` 里的 agenix 使用:

```nix
"/home/${myvars.username}/.ssh/id_ed25519"
```

而不是 `/etc/ssh/ssh_host_ed25519_key`。

不要在 Nix 配置里写 `~/.ssh/id_ed25519`。`~` 是 shell 展开规则，Nix 模块里不会自动展开。

当前 preservation 已经持久化了这些关键数据:

- `/etc/machine-id`
- `/etc/ssh/ssh_host_ed25519_key`
- `/etc/ssh/ssh_host_rsa_key`
- `/etc/agenix/`
- `/var/lib/nixos`
- `/var/lib/systemd`
- `/home/vitus/.ssh`
- `/home/vitus/nix-config`
- Home Manager 和 Nix profile 相关目录

## 6. 安装系统

在 ISO 里执行安装。以 `apollo` 为例:

```bash
cd /tmp/nix-config
nixos-install --root /mnt --flake .#apollo --no-root-password --show-trace --verbose
```

如果安装阶段因为 private `mysecrets` 拉取失败，可以先用能访问 GitHub private repo 的 SSH
key，或者临时把 desktop secrets 关掉完成 bootstrap。不要把 private key 复制进 `/nix/store`
或提交进仓库。

如果你临时关掉了 desktop secrets，这次安装不会生成 `/etc/agenix/*`，这是预期行为。

安装完成后不要马上重启。先把首启必需的状态放进 `/persistent`。

## 7. 第一次重启前必须处理的持久化数据

preservation 只会按规则把路径挂到
`/persistent`，不会自动帮你把已有文件搬过去。第一次安装后要手工准备:

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

如果你已经在 chroot 或 `nixos-enter` 里操作，路径可能是 `/etc/...` 和 `/persistent/...`，不要混用。

然后同步并重启:

```bash
sync
umount -R /mnt
reboot
```

## 8. 第一次启动后生成用户 agenix identity

登录新系统后，先确认当前用户是 `vitus`，并生成 agenix 要用的 key:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen -t ed25519 -a 256 -C "vitus@$(hostname)-agenix" -f ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

这把 key 现在有两个用途:

- 作为 agenix 的 NixOS 解密 identity
- 作为访问 private `mysecrets` input 的 SSH identity，前提是你把它加到 GitHub

确认 preservation 会保留它:

```bash
ls -la ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
```

## 9. Rekey private secrets

在能解密现有 secrets 的机器上，进入 private secrets 仓库，把新机器的 public key 加入 `secrets.nix`:

```bash
cat ~/.ssh/id_ed25519.pub
```

然后 rekey:

```bash
cd /path/to/my-secrets
agenix -r -i ~/.ssh/id_ed25519
git add .
git commit -m "rekey secrets for <host>"
git push
```

如果旧机器仍然使用 host key 解密，则用旧机器自己的 identity:

```bash
sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key
```

重点是: rekey 命令的 `-i` 参数必须是当前机器能解开旧 secrets 的私钥；新机器的
`~/.ssh/id_ed25519.pub` 必须已经在 recipients 里。

## 10. 更新本仓库的 secrets input 并正式切换

回到新机器后，把仓库放到用户目录。`/home/vitus/nix-config` 已经被 preservation 管理:

```bash
git clone https://github.com/Vitus213/nix-config.git ~/nix-config
cd ~/nix-config
```

如果你在 ISO 阶段修改过硬件配置但还没提交，需要把那些改动带回来。最稳妥的做法是在 ISO 阶段就提交到你自己的 repo，或者第一次启动后重新执行:

```bash
sudo nixos-generate-config
cp /etc/nixos/hardware-configuration.nix \
  ~/nix-config/hosts/olympians-$(hostname)/hardware-configuration.nix
```

然后更新 secrets input:

```bash
nix flake update mysecrets
```

如果 ISO 阶段临时关掉过 desktop secrets，现在先把它改回:

```nix
modules.secrets.desktop.enable = true;
```

先求值确认 agenix identity:

```bash
nix eval .#nixosConfigurations.$(hostname).config.age.identityPaths --json
```

对 `apollo`，期望输出类似:

```json
["/home/vitus/.ssh/id_ed25519"]
```

正式切换:

```bash
sudo nixos-rebuild switch --flake .#$(hostname) --show-trace --verbose
```

或者用仓库的 Justfile:

```bash
nix shell nixpkgs#just nixpkgs#nushell
just local debug
```

`just local` 会按当前 `hostname` 匹配 `nixosConfigurations`。如果主机名和 flake
output 名不一致，先用显式 flake 名称切换。

## 11. 常见错误和处理

### agenix 报 `/run/agenix.d/...tmp` 不存在

典型日志:

```text
chmod: cannot access '/run/agenix.d/4/totp-secrets.conf.tmp': No such file or directory
mv: cannot stat '/run/agenix.d/4/totp-secrets.conf.tmp': No such file or directory
Activation script snippet 'agenixInstall' failed
```

这通常不是 chmod 或 mv 的问题，而是更早的 `age` 解密失败。检查:

```bash
nix eval .#nixosConfigurations.$(hostname).config.age.identityPaths --json
ls -la ~/.ssh/id_ed25519
```

然后确认 `~/.ssh/id_ed25519.pub` 已经加入 private
secrets 仓库 recipients，并且已经 rekey、push、更新 `mysecrets` input。

### `/etc/agenix/*` 创建失败

典型日志:

```text
could not create target /etc/agenix/nix-access-tokens
could not create target /etc/agenix/totp-secrets.conf
```

如果前面同时有 agenix 解密失败，先修 rekey。`/etc/agenix/*` 是从 `/run/agenix.d/<generation>/*`
链接过去的，源文件不存在时 `/etc` 阶段自然会失败。

### 忘了把文件搬到 `/persistent`

症状:

- 重启后 `/etc/machine-id` 变化或丢失
- SSH host key 变化
- NetworkManager 配置消失
- 用户 `.ssh/id_ed25519` 不见了

处理方式:

1. 检查对应路径是否在 `preservation.nix` 的 `directories` 或 `files` 中
2. 把当前有效文件搬到 `/persistent` 对应位置
3. 重新 `nixos-rebuild switch`

### 不要在第一次部署时运行高影响切换

这些命令会构建并切换当前系统:

```bash
just local
just local debug
sudo nixos-rebuild switch --flake .#apollo
```

在确认硬件配置、secrets rekey、`age.identityPaths` 都正确前，不要反复执行。先用:

```bash
nix eval .#nixosConfigurations.apollo.config.age.identityPaths --json
nix eval .#evalTests --show-trace --print-build-logs --verbose
```

## 12. 最小检查清单

正式切换前确认:

- `hostname` 和 flake output 名一致，例如 `apollo`
- `hosts/olympians-<host>/hardware-configuration.nix` 来自当前机器
- `hosts/olympians-<host>/preservation.nix` 已导入
- `/persistent` 已经存在并挂载
- `/home/vitus/.ssh/id_ed25519` 存在
- `~/.ssh/id_ed25519.pub` 已加入 private secrets recipients
- private secrets 已 rekey 并 push
- `nix flake update mysecrets` 已执行
- `nix eval .#nixosConfigurations.<host>.config.age.identityPaths --json` 输出用户 key

这些都满足后，再执行 `nixos-rebuild switch`。
