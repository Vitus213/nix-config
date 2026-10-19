# NixOS 内核策略

本文记录当前仓库里 NixOS 主机的内核选择方式，重点是 `apollo`。

## 当前方案

- 主 `nixpkgs` 输入跟踪 `nixos-unstable`，具体锁定版本以 `flake.lock` 为准。
- `apollo` 和 `generic` 显式固定到 **6.18 LTS**：`pkgs.linuxPackages_6_18`。2026-10-19 求值版本为
  `6.18.56`，NVIDIA 驱动 `595.104.02`。
- rEFInd 当前只保留最新 1 个 NixOS generation；内核升级测试前应临时调高（见下文“验证方式”）。
- `nixos-unstable` 更新移除了旧的 `services.kmscon.fonts` 和 `services.kmscon.extraConfig`
  选项；当前仓库已迁移到 `services.kmscon.config.font-name`、`font-size` 和 `hwaccel`。
- `nixos-unstable` 更新移除了 `nodePackages`
  别名；当前仓库已将编辑器工具和 devShell 中的 Node 工具迁移到顶层包名。

### 为什么固定 LTS 系列

nixpkgs 会在内核系列 EOL 后**直接删除**它（把 `linuxPackages_X_Y` 改成 `throw`）。2026-10 之前
`apollo` 固定在非 LTS 的 `7.0`，主 nixpkgs 更新后 `linuxPackages_7_0`
被删，导致所有 NixOS 主机求值失败、CI 持续报错、apollo 无法 rebuild。

固定 LTS 系列（当前 6.18，nixpkgs 默认内核）同时满足两点：版本明确、便于回滚排查；维护周期长，不会因为 nixpkgs 更新突然失效。不使用
`linuxPackages_latest`，因为它会随 nixpkgs 跨大版本跳动。

当前 nixpkgs 中可用系列可以这样查看：

```bash
nix eval --raw .#nixosConfigurations.apollo.pkgs.linuxPackages.kernel.version   # nixpkgs 默认（LTS）
nix eval --raw .#nixosConfigurations.apollo.pkgs.linuxPackages_latest.kernel.version
```

## 配置入口

`hosts/olympians-apollo/default.nix`、`hosts/olympians-generic/default.nix`：

```nix
boot.kernelPackages = pkgs.linuxPackages_6_18;
```

NixOS 的 `boot.kernelPackages` 会同时切换内核以及依赖当前内核构建的包。`hosts/_shared/nvidia.nix`
里的 NVIDIA 驱动保持跟随 `config.boot.kernelPackages`，不单独指定驱动包。

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
```

如果将来要改到最新主线内核，把 `apollo` 配置改为：

```nix
boot.kernelPackages = pkgs.linuxPackages_latest;
```

下一个 LTS 系列进入 nixpkgs 后，再评估是否把固定版本切过去。不要直接手写内核 tarball，除非确实要维护自定义内核构建。

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
