# rEFInd 引导方案

本文记录 `apollo` 上用 rEFInd 管理 Intel NixOS 与 ZHITAI Windows 的配置。

## 实机引导位置（实施前检查）

- NixOS 所在磁盘：`/dev/sda`，型号 `INTEL SSDSC2KB960G8`。
- NixOS ESP：`/dev/sda1`，FAT32，UUID `C799-4063`，挂载到 `/boot`。
- NixOS 根分区：`/dev/sda2`，ext4，UUID `83ef9088-b0fc-49f1-bf67-51f8d8bfc2cb`。
- 切换前 NixOS 引导器：systemd-boot。
- 当前 NixOS 引导文件：
  - `/boot/EFI/systemd/systemd-bootx64.efi`
  - `/boot/EFI/BOOT/BOOTX64.EFI`
  - `/boot/loader/entries/nixos-generation-*.conf`
  - `/boot/loader/loader.conf`
- Windows 所在磁盘：`/dev/nvme1n1`，型号 `ZHITAI Ti600 1TB`。
- Windows ESP：`/dev/nvme1n1p1`，FAT32，UUID `492E-6B51`，分区标签 `EFI system partition`。
- Windows Boot Manager：
  - `EFI/Microsoft/Boot/bootmgfw.efi`
  - `EFI/Boot/bootx64.efi`
- Secure Boot：当前为 disabled。

## 当前方案

- rEFInd 安装在 Intel/NixOS ESP，也就是当前 `/boot`。
- 不改写 ZHITAI/Windows ESP，避免影响 Windows 自身引导与后续 Windows 更新。
- NixOS 由 rEFInd 生成的最新 NixOS generation 菜单项启动，主菜单只保留 1 个 NixOS 项。
- Windows 通过手动菜单项启动，直接指向 ZHITAI ESP 的 `\EFI\Microsoft\Boot\bootmgfw.efi`。
- rEFInd 主题使用开源项目 `evanpurkhiser/rEFInd-minimal`。
- rEFInd 主菜单只显示 NixOS 与 Windows 两个启动项，默认选择 NixOS。
- 当前 NixOS 求值使用的 rEFInd 包版本是 `0.14.2`；rEFInd 官方配置文档当前也引用 `0.14.2`。

## NixOS 配置

`flake.nix` 固定主题来源：

```nix
refind-minimal = {
  url = "github:evanpurkhiser/rEFInd-minimal";
  flake = false;
};
```

`hosts/olympians-apollo/default.nix` 启用 rEFInd：

```nix
boot.loader = {
  grub.enable = false;
  systemd-boot.enable = false;
  refind = {
    enable = true;
    maxGenerations = 1;
    extraConfig = ''
      include themes/rEFInd-minimal/theme.conf
      scanfor manual

      # Keep this as the only manual boot entry before generated NixOS entries.
      # The NixOS rEFInd module appends default_selection 2, so the second item is NixOS.
      menuentry "Windows" {
        icon /EFI/refind/themes/rEFInd-minimal/icons/os_win.png
        volume 8de23719-2dee-4179-a6c4-033a2f39df32
        loader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
  };
  efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot";
  };
};
```

`scanfor manual`
只启用手动菜单项和 NixOS 模块生成的 generation 菜单项，避免 rEFInd 自动扫描出额外 EFI
loader。`maxGenerations = 1` 让 NixOS generation 在主菜单中只保留最新一项。

NixOS rEFInd 模块会把 `extraConfig` 放在生成配置前面，并在后面追加自己的 `default_selection 2`。当前
`extraConfig` 里只有 1 个手动 Windows 项，NixOS 生成项排在第 2 位，因此最终默认进入 NixOS。

主题通过 `boot.loader.refind.additionalFiles` 复制到
`/boot/efi/refind/themes/rEFInd-minimal/`。不要在 ESP 上手工下载主题文件。NixOS 模块生成的 generation 项按 Linux
EFI stub loader 处理，rEFInd 默认会查找 `os_linux.png`；当前配置把主题目录中的 `os_linux.png` 覆盖为
`os_nixos.png`，因此 NixOS 菜单项显示 NixOS 图标。

## 验证步骤

实施前先做只读备份与记录：

```bash
lsblk -o NAME,PATH,MODEL,SIZE,TYPE,FSTYPE,LABEL,UUID,PARTUUID,PARTLABEL,MOUNTPOINTS
bootctl status --no-pager
sudo find /boot -maxdepth 5 \( -iname '*.efi' -o -iname '*.conf' -o -iname '*.cfg' \) -print
```

临时只读检查 Windows ESP：

```bash
sudo mkdir -p /tmp/zhitai-esp
sudo mount -o ro /dev/nvme1n1p1 /tmp/zhitai-esp
find /tmp/zhitai-esp -maxdepth 6 \( -iname '*.efi' -o -iname 'BCD' \) -print
sudo umount /tmp/zhitai-esp
```

配置验证：

```bash
nix eval .#nixosConfigurations.apollo.config.boot.loader.refind.enable
nix eval .#nixosConfigurations.apollo.config.boot.loader.systemd-boot.enable
nix eval .#nixosConfigurations.apollo.config.boot.loader.refind.maxGenerations
nix flake check --no-build
```

切换后检查：

```bash
sudo nixos-rebuild switch --flake .#apollo
bootctl status --no-pager
sudo find /boot/efi/refind -maxdepth 4 -type f -print
```

重启后验收：

- rEFInd 菜单显示 NixOS。
- rEFInd 菜单显示 Windows。
- rEFInd 主菜单只有 NixOS 与 Windows 两个启动项。
- rEFInd 默认选择 NixOS。
- NixOS 使用 NixOS 图标。
- NixOS 可正常启动。
- Windows 可正常启动。
- `rEFInd-minimal` 主题生效。

## 回滚方式

如果 rEFInd 启动异常，先从主板启动菜单选择原有 Intel ESP 的 systemd-boot fallback 或 Windows Boot
Manager。

NixOS 回滚配置时恢复：

```nix
boot.loader.systemd-boot.enable = true;
boot.loader.refind.enable = false;
boot.loader.efi.canTouchEfiVariables = true;
boot.loader.efi.efiSysMountPoint = "/boot";
```

然后执行：

```bash
sudo nixos-rebuild switch --flake .#apollo
```

如果 NVRAM 中仍保留 rEFInd 项，可在确认 systemd-boot 正常后再清理对应 EFI 启动项。

## 参考资料

- NixOS rEFInd options: <https://search.nixos.org/options?channel=unstable&query=refind>
- rEFInd 官方配置文档: <https://www.rodsbooks.com/refind/configfile.html>
- rEFInd minimal 主题: <https://github.com/evanpurkhiser/rEFInd-minimal>
