# 变更记录

本文件作为仓库配置变更的主线索引，按时间倒序记录。具体背景、当前行为、使用方式、验证和回滚步骤应写入关联专题文档。

## 2026-06-28

### 固定 Rime 小鹤双拼的中西文切换

- 影响范围：NixOS 桌面 Fcitx5 Rime 输入法、Fcitx5 全局快捷键、小鹤双拼中西文状态切换。
- 配置入口：`home/linux/gui/base/fcitx5/default.custom.yaml`、`home/linux/gui/base/fcitx5/config`、
  `home/linux/gui/base/fcitx5/profile`。
- 变更内容：保留 `double_pinyin_flypy` 作为唯一 Rime 输入方案；将 `Ctrl+Space` 绑定到
  `ascii_mode`，用于稳定切换小鹤双拼的中文状态和 Rime 西文状态
  `Ａ`；禁用 Rime 对 Shift、CapsLock 和左右 Control 的中西文切换处理；同时显式管理 Fcitx5 全局快捷键，清空 Shift 临时切换键，并将 Fcitx5
  Default 组收敛为仅包含 `rime`，避免日常在 `rime` 和英文键盘 `en` 之间轮转；Fcitx5 只保留
  `Ctrl+Alt+Space` 作为救援激活/关闭键。
- 验证方式：执行 `nixfmt --check home/linux/gui/base/fcitx5/default.nix`；重建或重新部署 Rime 后检查
  `~/.local/share/fcitx5/rime/build/default.yaml` 中的 `ascii_composer.switch_key` 和
  `key_binder.bindings`；检查 `~/.config/fcitx5/config` 中没有右 Shift 或 `Ctrl+Space` 全局绑定。
- 关联文档：[Fcitx5 与 Rime 小鹤双拼](./fcitx5-rime-input-method.md)、
  [Fcitx5 输入法](../home/linux/gui/base/fcitx5/README.md)。

### 启用 NixOS 微信与 QQ 沙箱安装

- 影响范围：`apollo`、`athena` NixOS 桌面用户包列表，微信 AppImage 封装，QQ Nixpak 封装。
- 配置入口：`home/linux/gui/base/misc.nix`、`hardening/bwraps/wechat.nix`、`hardening/nixpaks/default.nix`、
  `hardening/nixpaks/qq.nix`。
- 变更内容：启用 `bwraps.wechat` 和 `nixpaks.qq`；将微信 Linux AppImage 固定到
  `4.1.1.4`；QQ 局部固定到远端 Nixpkgs master 当前的 `3.2.29-2026-05-28` 源和 hash，不更新整个
  `nixpkgs-master` 输入；保留微信数据目录隔离和 QQ Nixpak 沙箱。
- 验证方式：执行
  `nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.home.packages --show-trace`；执行
  `nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace`。
- 关联文档：[Linux 微信与 QQ](./linux-im-apps.md)。

### 安装 CC Switch 并固定到 AeroSpace 10Other 工作区

- 影响范围：`artemis` macOS Homebrew 应用列表、AeroSpace 窗口自动分配、AeroSpace 使用文档。
- 配置入口：`modules/darwin/apps.nix`、`home/darwin/aerospace/aerospace.toml`。
- 变更内容：通过 Homebrew cask 安装 `cc-switch`；将 `com.ccswitch.desktop` 自动移动到
  `10Other`，也就是 `Option + 0`
  对应的其他工具工作区；同步校准 AeroSpace 文档中的当前工作区名称和显示器绑定。
- 验证方式：静态检查 Darwin Homebrew cask 列表和 AeroSpace `on-window-detected` 规则；执行
  `nix eval .#darwinConfigurations.artemis.config.homebrew.casks`。
- 关联文档：[AeroSpace 使用指南](./aerospace-usage.md)。

## 2026-06-21

### 恢复 rEFInd NixOS generation 保留数为 1

- 影响范围：`apollo` 主机 rEFInd 启动菜单。
- 配置入口：`hosts/olympians-apollo/default.nix`。
- 变更内容：将 `boot.loader.refind.maxGenerations` 从内核测试期的 `3` 恢复为
  `1`，主菜单只保留最新 NixOS generation；内核测试需要回滚入口时再临时调高。
- 验证方式：执行 `nix eval .#nixosConfigurations.apollo.config.boot.loader.refind.maxGenerations`。
- 关联文档：[rEFInd 引导方案](./refind-boot.md)、[NixOS 内核策略](./nixos-kernel.md)。

### 修复 apollo rebuild 的 Catppuccin VSCode 与 Neovim 生成冲突

- 影响范围：`apollo` 主机 Home Manager、VSCode Catppuccin 扩展、Neovim AstroNvim 配置入口。
- 配置入口：`flake.lock`、`home/base/tui/editors/neovim/default.nix`。
- 变更内容：将 `catppuccin/nix` 更新到 `2026-06-19` 的上游版本，使 VSCode
  Catppuccin 扩展使用已修复的 pnpm 依赖闭包；显式禁用 Home Manager 生成的
  `.config/nvim/init.lua`，并关闭 Neovim Python3/Ruby
  provider，避免它额外写入入口文件并与当前 AstroNvim 目录链接冲突。
- 验证方式：执行
  `nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace`。
- 关联文档：[Neovim](../home/base/tui/editors/neovim/README.md)。

### 将 apollo 固定到 Linux 7.0 内核系列

- 影响范围：`apollo` 主机 NixOS 内核、rEFInd 回滚入口、主 `nixpkgs` 与 `home-manager` 输入、NixOS
  desktop 字体控制台配置、编辑器工具包、devShell。
- 配置入口：`hosts/olympians-apollo/default.nix`、`modules/nixos/desktop/fonts.nix`、`home/base/tui/editors/packages.nix`、`outputs/default.nix`、`flake.lock`。
- 变更内容：更新主 `nixpkgs` 到 `2026-06-16` 的 `nixos-unstable`；将 `apollo` 的
  `boot.kernelPackages` 固定为 `pkgs.linuxPackages_7_0`，当前求值内核为 `7.0.12`；同步更新
  `home-manager` 到 `2026-06-20` 的 master，避免 Home Manager 模块与新 nixpkgs 不匹配；将已移除的
  `services.kmscon.fonts`/`extraConfig` 迁移到 `services.kmscon.config`；将已移除的 `nodePackages.*`
  引用迁移到顶层包名；记录 rEFInd 当前只保留最新 1 个 NixOS
  generation，内核测试需要回滚入口时再临时调高。
- 验证方式：执行 `nix eval` 检查内核版本与 rEFInd generation 保留数；执行
  `nix build .#nixosConfigurations.apollo.config.system.build.toplevel --dry-run --show-trace`；执行
  `nix flake check --no-build`。
- 关联文档：[NixOS 内核策略](./nixos-kernel.md)、[rEFInd 引导方案](./refind-boot.md)。

### 优化 rEFInd 菜单项、默认启动与 NixOS 图标

- 影响范围：`apollo` 主机 rEFInd 启动菜单。
- 配置入口：`hosts/olympians-apollo/default.nix`。
- 变更内容：将 rEFInd NixOS
  generation 主菜单项限制为最新 1 个；保留 Windows 手动启动项；禁用自动扫描额外启动项；默认选择 NixOS；将 rEFInd
  minimal 主题中的 Linux 图标入口覆盖为 NixOS 图标，确保 NixOS 菜单项显示 NixOS 图标。
- 验证方式：执行 `nix eval` 检查 rEFInd 版本、`maxGenerations`、`extraConfig` 与主题附加文件；执行
  `nix flake check --no-build`。
- 关联文档：[rEFInd 引导方案](./refind-boot.md)。

### 建立文档记录与 changelog 规约

- 影响范围：自动化代理工作规约、配置变更文档流程。
- 配置入口：`AGENTS.md`。
- 变更内容：要求所有配置变更都维护完整专题文档，并在本文件追加主线记录。
- 验证方式：静态检查 `AGENTS.md` 与本文件内容一致。
- 关联文档：本文件。

### 启用 rEFInd 管理 Intel NixOS 与 ZHITAI Windows 引导

- 影响范围：`apollo` 主机引导配置。
- 配置入口：`hosts/olympians-apollo/default.nix`、`flake.nix`。
- 变更内容：禁用 systemd-boot，启用 rEFInd；rEFInd 安装到 Intel/NixOS
  ESP，并通过手动菜单项链式启动 ZHITAI ESP 上的 Windows Boot Manager；主题使用
  `evanpurkhiser/rEFInd-minimal` flake input。
- 验证方式：只读检查块设备、当前 `/boot` 内容、ZHITAI ESP 内容、Secure Boot 状态；执行
  `nix flake check --no-build`、`nix build .#nixosConfigurations.apollo.config.system.build.installBootLoader --no-link`、`nix build .#nixosConfigurations.apollo.config.system.build.toplevel --dry-run`。
- 关联文档：[rEFInd 引导方案](./refind-boot.md)。
