# NixOS 内核策略

本文记录当前仓库里 NixOS 主机的内核选择方式，重点是 `apollo`。

## 当前方案

- 主 `nixpkgs` 输入使用 `github:nixos/nixpkgs/nixos-unstable`。
- 当前 `flake.lock` 将主 `nixpkgs` 固定到 `0c88e1f2bdb93d5999019e99cb0e61e1fe2af4c5`。
- 这个 `nixpkgs` 求值出的 NixOS 版本是 `26.11.20260702.6517942`。
- `home-manager` 输入跟随主 `nixpkgs`，当前固定到 `abfad3d2958c9e6300a883bd443512c55dfeb1be`。更新主
  `nixpkgs` 时应同步更新它，避免模块 API 与包集合不匹配。
- `apollo` 显式使用 `pkgs.linuxPackages_7_0`。
- 当前 `apollo` 求值出的内核版本是 `7.0.14`。
- rEFInd 当前只保留最新 1 个 NixOS
  generation，避免启动菜单长期显示旧 generation；内核升级测试前可临时调高。
- `nixos-unstable` 更新移除了旧的 `services.kmscon.fonts` 和 `services.kmscon.extraConfig`
  选项；当前仓库已迁移到 `services.kmscon.config.font-name`、`font-size` 和 `hwaccel`。
- `nixos-unstable` 更新移除了 `nodePackages`
  别名；当前仓库已将编辑器工具和 devShell 中的 Node 工具迁移到顶层包名，例如
  `yaml-language-server`、`typescript-language-server` 和 `prettier`。

`kernel.org` 在 2026-07-04 的状态：

- 最新 stable 是 `7.1.2`。
- `7.0.14` 已标记为 EOL。

当前不直接使用 `pkgs.linuxPackages_latest`，因为它会跟随 nixpkgs 中最新主线内核分支移动。`apollo`
带 NVIDIA 闭源/开源内核模块与日常桌面负载，短期固定到 `linuxPackages_7_0` 更利于回滚和排查；但由于
`7.0.14` 已 EOL，下一次内核维护应优先评估升级到当前 nixpkgs 中仍受维护的内核系列。

## 配置入口

`hosts/olympians-apollo/default.nix`：

```nix
boot.kernelPackages = pkgs.linuxPackages_7_0;
```

NixOS 的 `boot.kernelPackages`
会同时切换内核以及依赖当前内核构建的包。`hosts/olympians-apollo/nvidia.nix` 里的 NVIDIA 驱动保持跟随
`config.boot.kernelPackages`，不单独指定驱动包。

## 升级流程

更新主 `nixpkgs` 和 `home-manager`：

```bash
nix flake update nixpkgs
nix flake update home-manager
```

如果更新后出现 NixOS 模块选项移除提示，按提示迁移本仓库模块，不要用 `mkForce` 或忽略断言绕过。

确认目标内核版本：

```bash
nix eval --raw .#nixosConfigurations.apollo.config.boot.kernelPackages.kernel.version
nix eval --raw .#nixosConfigurations.apollo.pkgs.linuxPackages_7_0.kernel.version
```

如果将来要改到最新主线内核，把 `apollo` 配置改为：

```nix
boot.kernelPackages = pkgs.linuxPackages_latest;
```

如果只想继续使用
`7.0.x`，需要先确认 nixpkgs 中是否仍提供安全更新。不要直接手写内核 tarball，除非确实要维护自定义内核构建。

## 验证方式

低风险验证：

```bash
nix eval --raw .#nixosConfigurations.apollo.config.boot.kernelPackages.kernel.version
nix eval .#nixosConfigurations.apollo.config.boot.loader.refind.maxGenerations
nix build .#nixosConfigurations.apollo.config.system.build.toplevel --dry-run --show-trace
nix flake check --no-build
```

应用到下一次启动：

```bash
sudo nixos-rebuild boot --flake .#apollo
```

重启后确认：

```bash
uname -r
```

如果需要在启动菜单保留旧内核回滚入口，可在内核测试前临时把 `boot.loader.refind.maxGenerations`
调高。

## 回滚方式

如果新内核无法启动，在 rEFInd 菜单选择旧的 NixOS generation。

启动到旧 generation 后，将 `hosts/olympians-apollo/default.nix` 恢复为默认内核：

```nix
boot.kernelPackages = pkgs.linuxPackages;
```

或者直接删除 `boot.kernelPackages` 这一行，让主机跟随当前 nixpkgs 默认内核。

然后执行：

```bash
sudo nixos-rebuild boot --flake .#apollo
```

## 参考资料

- Kernel.org releases: <https://www.kernel.org/releases.json>
- NixOS `boot.kernelPackages` options:
  <https://search.nixos.org/options?channel=unstable&query=boot.kernelPackages>
- Nixpkgs Linux kernel definitions:
  <https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/linux-kernels.nix>
