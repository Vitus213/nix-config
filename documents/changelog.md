# 变更记录

本文件作为仓库配置变更的主线索引，按时间倒序记录。具体背景、当前行为、使用方式、验证和回滚步骤应写入关联专题文档。

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
