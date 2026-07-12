# Orca 桌面应用

本文记录 StablyAI Orca 在本仓库中的安装方式。

## 当前行为

Linux 图形桌面通过 Home Manager 安装 Orca。配置入口是 `home/linux/gui/base/misc.nix`，实际软件包由
`overlays/stably-orca/default.nix` 提供。

当前固定版本为 `1.4.137`，来源是官方 GitHub release 的 Linux AppImage：

- release: <https://github.com/stablyai/orca/releases/tag/v1.4.137>
- AppImage: <https://github.com/stablyai/orca/releases/download/v1.4.137/orca-linux.AppImage>
- Nix hash: `sha256-jHQSL6aTSnZEZgsKT7HxyXZppQwatUgiF1UPzR4fyZg=`

nixpkgs 中已有的 `pkgs.orca` 是 GNOME 屏幕阅读器，不是 StablyAI Orca。本仓库使用 `pkgs.stably-orca`
作为属性名避免冲突，但安装后的主命令仍是官方命令 `orca`。

Orca 使用内置的 xterm.js 终端界面，不会启动 Ghostty、Foot 等外部终端模拟器。软件包通过 `makeWrapper`
只为 Orca 进程设置
`SHELL=${lib.getExe pkgs.nushell}`，因此新建终端默认运行当前 nixpkgs 中的 Nushell，不会改变系统登录 shell、Ghostty 启动链路或其他图形应用的环境。

Orca `1.4.137`
尚未提供 Linux 默认 shell 设置，其 shell-ready 启动包装仍只专门支持 Bash 和 Zsh；但该版本会在 PTY 启动前校验 Unix
daemon 使用的绝对 shell 路径，并将实际 shell 传播到子进程环境。当前包装器提供有效的 Nushell 绝对路径，因此 Nushell 会以
`nu -l`
登录模式启动；普通交互终端可正常使用，Orca 自动投递 Agent 启动命令时不会获得 Bash/Zsh 专用的 shell-ready 标记。

Orca AppImage 通过 nixpkgs 的 `appimageTools.wrapAppImage` 运行在 `buildFHSEnv`
创建的 FHS 环境中。该环境会重新创建 `/etc`，因此默认看不到宿主机的 `/etc/agenix`。当前 overlay 使用
`--ro-bind-try`，把宿主机的整个 `/etc/agenix`
只读映射到 FHS 环境中的相同路径，保证 Apollo 和 Athena 的 Nushell 配置可以继续 `source`
工作 alias。Orca 及其内置终端可以读取该目录中所有由当前用户权限允许读取的 secrets；未提供该目录的主机仍可正常启动 Orca。

Niri 会按窗口的 `app-id="orca"` 将 Orca 默认打开到 `5code` 工作区并最大化。窗口规则位于
`home/linux/gui/niri/conf/windowrules.kdl`。

Home Manager 通过 `home/linux/gui/base/xdg/autostart.nix` 将 Orca 自带的 `orca.desktop` 安装到
`~/.config/autostart/orca.desktop`。Orca 会在用户进入 Niri 图形会话且 XDG
autostart 就绪后自动启动，不会在尚无 Wayland、D-Bus 和 portal 环境的系统引导阶段启动。

## 使用方式

更新 Home Manager 或 NixOS 配置后，Orca 会在下次登录 Niri 图形会话时自动启动。也可以从应用启动器打开
`Orca`，或在终端运行：

```bash
orca
```

部署涉及 `SHELL`
或 FHS 挂载变更时，需要先完全退出部署前启动的所有 Orca 进程，再重新打开 Orca；已经运行的进程无法获得新的 mount
namespace。随后在 `Settings -> Terminal -> Manage Sessions` 中执行
`Restart daemon`，关闭旧终端并新建终端。Orca 的 terminal
daemon 会跨应用重启继续运行，只关闭窗口不足以应用新的 `SHELL` 或挂载配置。

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

如果不再需要登录后自动启动，从 `home/linux/gui/base/xdg/autostart.nix` 的 `xdg.autostart.entries`
中移除 `stably-orca` 桌面文件条目。Orca 仍会保留在应用启动器中并可手动运行。

如果需要撤销 agenix 目录映射，从 `overlays/stably-orca/default.nix` 移除
`extraBwrapArgs`。撤销后 Orca 仍可启动，但内置 Nushell 无法再通过
`/etc/agenix/alias-for-work.nushell` 加载工作 alias。

如果只需回滚 Nushell 默认值，从 `overlays/stably-orca/default.nix` 移除 `makeWrapper`、`nushell`、
`nativeBuildInputs` 和 `wrapProgram ... --set SHELL ...`，重新构建后重启 Orca terminal daemon。

如果 Orca AppImage 整体启动异常，回滚步骤是：

1. 从 `home/linux/gui/base/misc.nix` 移除 `stably-orca`。
2. 如果短期不再使用本地包，删除 `overlays/stably-orca/` 并同步 `overlays/README.md`。
3. 重新运行低风险求值验证。

## 验证

本次配置使用以下低风险检查：

```bash
nix build --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in flake.nixosConfigurations.apollo.pkgs.stably-orca' --impure --no-link --print-build-logs
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.stably-orca' --impure
nix eval --json --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); cfg = flake.nixosConfigurations.apollo.config; lib = flake.inputs.nixpkgs.lib; in builtins.any (pkg: (pkg.pname or "") == "orca" && lib.getVersion pkg == "1.4.137") cfg.home-manager.users.vitus.home.packages' --impure
nix eval --json --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in map toString flake.nixosConfigurations.apollo.config.home-manager.users.vitus.xdg.autostart.entries' --impure
nix build --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in flake.nixosConfigurations.apollo.config.home-manager.users.vitus.home.activationPackage' --impure --no-link --print-out-paths
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getExe pkgs.nushell' --impure
out=$(nix build --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in flake.nixosConfigurations.apollo.pkgs.stably-orca' --impure --no-link --print-out-paths)
grep '^export SHELL=' "$out/bin/orca"
grep -- '--ro-bind-try /etc/agenix /etc/agenix' "$out/bin/.orca-wrapped"
"$(nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getExe pkgs.nushell' --impure)" -l -c 'version | get version'
```

未执行 `just local` 或 `nixos-rebuild switch`，因为这些命令会切换当前系统。
