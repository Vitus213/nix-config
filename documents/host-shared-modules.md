# 主机共享模块与仓库清理（W1 + W2）

本文记录 2026-08-15 对 nix-config 的可读性、精简与内聚优化：删除死代码、主机层去重、消除
`mkForce`、统一 darwin overlay。

## 背景

优化前存在三类问题：

1. **死代码**：`ghostty`、`helix`、`blender-bin`、`nixos-apple-silicon`、`disko`、 `lanzaboote`
   等 flake input 无任何引用；`secureboot.nix` 三份副本无主机导入；
   `outputs/aarch64-linux/`（空主机）、`modules/nixos/server/`、
   `lib/genK3s*.nix`、`lib/genKubeVirt*.nix`、`lib/colmenaSystem.nix`、
   `lib/attrs.nix`、`home/base/core/editors/`、`home/linux/core.nix`、
   `modules/darwin/broken-packages.nix`、`.pre-commit-config.yaml`、 `packages/`
   空目录等均已无使用方。
2. **主机层重复**：`netdev-mount.nix`（三份 md5 一致）、`nvidia.nix`（两份一致）、
   `preservation.nix`（apollo/athena 逐字节一致，约 400 行）逐主机复制；三台主机 `default.nix` 重复
   `zramSwap.enable = lib.mkForce false`、 `services.sunshine.enable = lib.mkForce true`、
   `services.tuned.ppdSettings.main.default = lib.mkForce "performance"` 样板。
3. **语义不一致**：`modules/darwin/broken-packages.nix` 与 `lib/macosSystem.nix`
   内联 overlay 是同一份"移除 darwin 不兼容包"列表的两个拷贝。其中 `broken-packages.nix` 走
   `nixpkgs.overlays`，而 darwin 的 `nixpkgs.pkgs` 由 `macosSystem.nix` 显式构造，`nixpkgs.overlays`
   选项被忽略——实测 darwin 的 bun 仍为 1.3.13（overlays/bun 若生效应为 1.3.14），证明该文件从未生效，属死代码。

## 当前配置如何工作

### 主机共享模块：`hosts/_shared/`

多台 NixOS 主机复用的文件统一放 `hosts/_shared/`，主机 `default.nix` 用相对路径导入：

- `hosts/_shared/preservation.nix`：`/persistent` 持久化映射（apollo、athena 共用；generic 未启用）
- `hosts/_shared/nvidia.nix`：NVIDIA 驱动与图形配置（apollo 启用；athena、generic 注释保留，按需解开）
- `hosts/_shared/netdev-mount.nix`：davfs 支持（三台主机共用）

新增主机时只复制硬件差异文件（`hardware-configuration.nix`、`home.nix`、
`niri-hardware.kdl`），共享能力直接导入 `_shared/`。

### mkForce 消除：基础模块改 mkDefault

三个基础模块的默认值改为 `lib.mkDefault`，主机可用普通赋值覆盖：

- `modules/nixos/base/zram.nix`：`zramSwap.enable = lib.mkDefault true;`
- `modules/nixos/desktop/power.nix`：`ppdSettings.main.default = lib.mkDefault "balanced";`
- `modules/nixos/desktop/networking/remote-desktop.nix`：
  `services.sunshine.enable = lib.mkDefault false;`

主机侧写法随之简化（以 apollo 为例）：

```nix
zramSwap.enable = false;
services.sunshine.enable = true;
services.tuned.ppdSettings.main.default = "performance";
```

generic 保留一处 `nix.extraOptions = lib.mkForce`：它不启用 secrets，
`/etc/agenix/nix-access-tokens` 不存在，必须覆盖 `modules/nixos/base/nix.nix` 里的
`!include`，否则启动时 nix 报错。该处已加注释说明。

### darwin overlay 单一来源

"移除 darwin 不兼容包"与 direnv CGO 修复的 overlay 只保留在 `lib/macosSystem.nix` 的 `nixpkgs.pkgs`
构造处；失效的 `modules/darwin/broken-packages.nix` 已删除。

### home linux 入口链式化

`home/linux/gui.nix` 改为继承
`./tui.nix`（tui.nix 已包含 base/core、base/tui、home.nix），GUI 只追加 `../base/gui` 与
`./gui`，不再重复罗列 base 入口。

### src 文件签名注释修正

`outputs/*/src/*.nix`
原先携带"参数不可删除"的英文注释，但没解释原因。实测确认该注释是正确约束：haumea 的
`defaultWith import` loader 只把函数签名里显式命名的参数从 args 取出传入，`@args`
也只包含这些命名参数；而 `mylib.nixosSystem (modules-niri // args)` 依赖
`system`、`genSpecialArgs`、 `inputs`、`myvars` 经 `@args` 透传。删除签名参数会导致
`function called without required argument 'system'`。因此参数全部保留，仅将注释改写为说明这一机制，防止后人误删。

## 删除清单

- flake inputs：`ghostty`、`helix`、`blender-bin`、`nixos-apple-silicon`、`disko`、
  `lanzaboote`（lock 同步修剪约 300 行，存活 input 的 pin 未变）
- `Justfile`：修复 `up-nix`（原先引用不存在的 `nixpkgs-stable`/`nixpkgs-master`，改为更新真实存在的
  `nixpkgs nixpkgs-darwin nixpkgs-patched`）；删除无对应主机的 colmena / KubeVirt / K3s 命令组
- 主机文件：三份 `secureboot.nix`（无主机导入）、generic 的 `nvidia.nix` 与
  `preservation.nix`（均被注释、未生效）
- 目录：`outputs/aarch64-linux/`、`modules/nixos/server/`、
  `home/base/core/editors/`、`.Trash-1000/`、空 `packages/`
- 库文件：`lib/colmenaSystem.nix`、`lib/genK3sAgentModule.nix`、
  `lib/genK3sServerModule.nix`、`lib/genKubeVirtGuestModule.nix`、
  `lib/genKubeVirtHostModule.nix`、`lib/attrs.nix`
- 模块：`modules/darwin/broken-packages.nix`（overlay 不生效的死代码）
- 其他：`home/linux/core.nix`（无导入方）、`.pre-commit-config.yaml`（空文件、未跟踪）、 `utils.nu`
  中仅供已删除 VM 命令使用的 `upload-vm` 函数

## 使用方式

- 部署命令不变：`just local`、`sudo nixos-rebuild switch --flake .#apollo` 等
- 更新 nixpkgs 用修复后的 `just up-nix`
- 新主机参考 `hosts/README.md` 的添加步骤

## 验证

- `nix eval .#evalTests` → `true`
- 35 项关键属性语义快照（zram/sunshine/tuned/bootloader/networking/
  preservation.preserveAt 等）与变更前基线逐项对比：零差异
- `hermes` activationPackage drvPath 与基线完全一致
- apollo/athena/generic 的 toplevel
  drvPath 变化仅源于模块文件路径移动（NixOS 文档构建嵌入模块声明路径），语义未变
- artemis 在 x86_64-linux 上无法深 eval（平台不匹配），由 evalTests 覆盖

## 回滚方式

所有变更均为普通 git 提交；如需回滚：

```bash
git revert <本次优化涉及的提交>
```

若只需恢复某个主机行为（如重新启用 Secure Boot），按 lanzaboote 官方文档重建 `secureboot.nix`
并在主机 `default.nix` 导入即可。
