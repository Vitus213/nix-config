# 通用 NixOS 桌面 Host

`generic` 是从 `apollo` 复制并裁剪出的通用 NixOS 桌面配置，入口是:

- `outputs/x86_64-linux/src/olympians-generic.nix`
- `hosts/olympians-generic/default.nix`
- `hosts/olympians-generic/home.nix`

## 当前行为

- flake output 名称是 `generic`
- 主机名是 `generic`
- 保留 NixOS desktop、Home Manager、Niri、常用 GUI/TUI 模块
- 不导入 `secrets/nixos.nix`
- 不启用 `modules.secrets.desktop.enable`
- 不导入 `preservation.nix`
- 使用 `systemd-boot`，不使用 Apollo 的 rEFInd/Windows 手动启动项
- 默认关闭 NVIDIA 和 force-X11-compat 主机选项
- 不加载 `/etc/agenix/alias-for-work.nushell`
- 不生成依赖 `/etc/agenix/github_token` 的 GitHub CLI auth
- 不链接 `/etc/agenix/totp-secrets.conf`
- 不配置 `192.168.*` 使用 `/etc/agenix/ssh-key-romantic`

## 使用方式

在新机器上先生成硬件配置，再替换通用 host 里的复制文件:

```bash
nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix \
  /tmp/nix-config/hosts/olympians-generic/hardware-configuration.nix
```

然后安装:

```bash
cd /tmp/nix-config
nixos-install --root /mnt --flake .#generic --no-root-password --show-trace --verbose
```

如果已经进入系统:

```bash
sudo nixos-rebuild switch --flake .#generic --show-trace --verbose
```

## 变成正式主机

如果某台机器后续要长期维护，建议复制 `hosts/olympians-generic/` 为新的主机目录，再改:

- `hosts/olympians-<name>/default.nix`
- `hosts/olympians-<name>/home.nix`
- `outputs/x86_64-linux/src/olympians-<name>.nix`
- `hardware-configuration.nix`

需要个人 secrets 或 preservation 时，再按专题文档单独接回，不要直接在 `generic` 上启用。
