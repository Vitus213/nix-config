# Orca 桌面应用

本文记录 StablyAI Orca 在本仓库中的安装方式。

## 当前行为

Linux 图形桌面通过 Home Manager 安装 Orca。配置入口是 `home/linux/gui/base/misc.nix`，实际软件包由
`overlays/stably-orca/default.nix` 提供。

当前固定版本为 `1.4.134`，来源是官方 GitHub release 的 Linux AppImage：

- release: <https://github.com/stablyai/orca/releases/tag/v1.4.134>
- AppImage: <https://github.com/stablyai/orca/releases/download/v1.4.134/orca-linux.AppImage>
- Nix hash: `sha256-LkPMYi+prl1aKDzBJ02vCu2PXJAVmF3O2bOwXiQeoWw=`

nixpkgs 中已有的 `pkgs.orca` 是 GNOME 屏幕阅读器，不是 StablyAI Orca。本仓库使用 `pkgs.stably-orca`
作为属性名避免冲突，但安装后的主命令仍是官方命令 `orca`。

Niri 会按窗口的 `app-id="orca"` 将 Orca 默认打开到 `5code` 工作区并最大化。窗口规则位于
`home/linux/gui/niri/conf/windowrules.kdl`。

## 使用方式

更新 Home Manager 或 NixOS 配置后，可以从应用启动器打开 `Orca`，也可以在终端运行：

```bash
orca
```

Orca 是 Electron 桌面应用，`orca --version`
会启动应用本体，不作为版本检查命令使用。版本以 Nix 求值结果为准。

## 更新方式

升级 Orca 时修改 `overlays/stably-orca/default.nix` 中的：

- `version`
- AppImage `url`
- `hash`

hash 可用以下命令重新获取：

```bash
nix store prefetch-file --json https://github.com/stablyai/orca/releases/download/v<version>/orca-linux.AppImage
```

更新后同步本文件、`documents/application-version-audit.md` 和 `documents/changelog.md`。

## 回滚方式

如果 Orca AppImage 启动异常，回滚步骤是：

1. 从 `home/linux/gui/base/misc.nix` 移除 `stably-orca`。
2. 如果短期不再使用本地包，删除 `overlays/stably-orca/` 并同步 `overlays/README.md`。
3. 重新运行低风险求值验证。

## 验证

本次配置使用以下低风险检查：

```bash
nix build --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in flake.nixosConfigurations.apollo.pkgs.stably-orca' --impure --no-link --print-build-logs
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.stably-orca' --impure
nix eval --json --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); cfg = flake.nixosConfigurations.apollo.config; lib = flake.inputs.nixpkgs.lib; in builtins.any (pkg: (pkg.pname or "") == "orca" && lib.getVersion pkg == "1.4.134") cfg.home-manager.users.vitus.home.packages' --impure
```

未执行 `just local` 或 `nixos-rebuild switch`，因为这些命令会切换当前系统。
