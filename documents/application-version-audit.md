# 应用版本审计

本文件记录仓库中用户会直接启动的主要应用版本来源、当前求值版本、是否局部固定、是否使用 NixPak。普通 CLI 工具和系统基础包通常跟随对应
`nixpkgs` 输入统一更新，不在这里逐项列出。

## 当前结论

- Zed 已通过 `home/linux/gui/base/editors.nix` 安装，使用主 `pkgs.zed-editor`，当前求值版本为
  `1.6.3`。
- 当前 NixPak 只封装 3 个应用：`nixpaks.firefox`、`nixpaks.telegram-desktop`、`nixpaks.qq`。
- 明确局部固定、局部修补或不完全跟随主 `nixpkgs`
  统一更新的用户可见应用/数据包括 Bun、QQ、WeChat、StablyAI Orca、Rime Ice、Catppuccin
  VSCode 扩展，以及 AAGL 游戏启动器。
- Linux 桌面常规应用默认跟随主 `nixpkgs` 输入，也就是
  `github:nixos/nixpkgs/nixos-unstable`；仓库不再为常规软件额外维护 `nixpkgs-stable` 或
  `nixpkgs-master` 包集合。

## 应用清单

| 应用                   | 当前版本             | 配置入口                                                                                    | 版本来源                                                            | 固定/修补 | NixPak | 处理建议                                                                        |
| ---------------------- | -------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | --------- | ------ | ------------------------------------------------------------------------------- |
| Zed                    | `1.6.3`              | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.zed-editor`                                   | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| Orca                   | `1.4.134`            | `home/linux/gui/base/misc.nix`、`overlays/stably-orca/default.nix`                          | 官方 GitHub release 的 `orca-linux.AppImage`                        | 是        | 否     | 使用 `pkgs.stably-orca` 避免与 GNOME `pkgs.orca` 冲突；更新时同步 `orca.md`     |
| Cursor                 | `3.7.19`             | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.code-cursor`                                  | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| VSCode                 | `1.124.2`            | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.vscode`                                       | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| Catppuccin VSCode 扩展 | `3.19.0`             | `home/base/core/theme.nix`                                                                  | `catppuccin/nix` 的 VSCode port，本仓库修正 pnpm `nodejs-slim` 参数 | 是        | 否     | 等上游改用 `nodejs-slim` 后移除本地包覆盖                                       |
| WPS Office CN          | `12.1.2.25882`       | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.wpsoffice-cn`                                 | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| Firefox                | `152.0`              | `home/linux/gui/base/browsers.nix`、`hardening/nixpaks/firefox.nix`                         | 主 `nixpkgs` 的 `pkgs.firefox`                                      | 否        | 是     | 保留 NixPak 沙箱，版本跟随主 `nixpkgs`                                          |
| Google Chrome          | `149.0.7827.114`     | `home/linux/gui/base/browsers.nix`                                                          | 主 `nixpkgs` 的 `pkgs.google-chrome`                                | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| Chromium               | `149.0.7827.114`     | `home/linux/gui/base/browsers.nix`                                                          | aarch64 fallback，主 `nixpkgs` 的 `pkgs.chromium`                   | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| Telegram Desktop       | `6.8.2`              | `home/linux/gui/base/misc.nix`、`hardening/nixpaks/telegram-desktop.nix`                    | 主 `nixpkgs` 的 `pkgs.telegram-desktop`                             | 否        | 是     | 保留 NixPak 沙箱，版本跟随主 `nixpkgs`                                          |
| QQ                     | `3.2.29-2026-05-28`  | `home/linux/gui/base/misc.nix`、`hardening/nixpaks/default.nix`、`hardening/nixpaks/qq.nix` | 局部固定官方 QQ deb                                                 | 是        | 是     | 后续更新需改 URL/hash 并同步 `linux-im-apps.md`                                 |
| WeChat                 | `4.1.1.4`            | `home/linux/gui/base/misc.nix`、`hardening/bwraps/wechat.nix`                               | 局部固定官方 AppImage                                               | 是        | 否     | 后续更新需改 URL/hash 并同步 `linux-im-apps.md`                                 |
| Rime Ice               | `2026-06-21-3ec476e` | `overlays/fcitx5/default.nix`                                                               | 固定 GitHub rev                                                     | 是        | 否     | 更新词库时改 rev/hash 并同步 Fcitx5 文档                                        |
| Bun                    | `1.3.14`             | `home/base/core/npm.nix`、`overlays/bun/default.nix`                                        | 临时 overlay 覆盖主 `nixpkgs` 的 `pkgs.bun`                         | 是        | 否     | 用于安装最新版 Pi / Oh My Pi；待 nixpkgs 合入后移除 overlay                     |
| OpenCode               | 用户级 npm           | `home/base/core/npm.nix`、`home/base/tui/shell/default.nix`                                 | `npm install -g opencode-ai@latest`                                 | 否        | 否     | 跟随 npm 更新，不通过 Nix 固定                                                  |
| Pi / Oh My Pi          | 用户级 bun           | `home/base/core/npm.nix`、`documents/nushell-ai-agent-aliases.md`                           | `bun install -g @oh-my-pi/pi-coding-agent@latest oh-my-pi@latest`   | 否        | 否     | 跟随 bun 更新，不通过 Nix 固定                                                  |
| Clash Verge Rev        | `2.5.1`              | `modules/nixos/desktop/networking/clash-verge.nix`                                          | 主 `nixpkgs` 的 `pkgs.clash-verge-rev`                              | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| Guix                   | `1.5.0`              | `modules/nixos/desktop/guix.nix`                                                            | 主 `nixpkgs` 的 `pkgs.guix`                                         | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| Noctalia Shell         | `4.4.3`              | `home/linux/gui/base/noctalia/default.nix`                                                  | `nixpkgs-patched` 的 `pkgs-patched.noctalia-shell`                  | 否        | 否     | 跟随 `nixpkgs-patched` 更新                                                     |
| Voxtype Vulkan         | `0.7.2`              | `home/linux/gui/base/voice-input.nix`                                                       | 主 `nixpkgs` 的 `pkgs.voxtype-vulkan`                               | 否        | 否     | 跟随主 `nixpkgs` 更新                                                           |
| Anime Game Launcher    | `3.19.5`             | `modules/nixos/desktop/gaming.nix`                                                          | `aagl-gtk-on-nix` 的 `release-25.11` input                          | 是        | 否     | 当前保留 25.11 分支并关闭 release 检查；等上游提供匹配主 `nixpkgs` 的分支后更新 |
| Honkers Railway        | `1.15.0`             | `modules/nixos/desktop/gaming.nix`                                                          | `aagl-gtk-on-nix` 的 `release-25.11` input                          | 是        | 否     | 当前保留 25.11 分支并关闭 release 检查；等上游提供匹配主 `nixpkgs` 的分支后更新 |
| Sleepy Launcher        | `1.6.6`              | `modules/nixos/desktop/gaming.nix`                                                          | `aagl-gtk-on-nix` 的 `release-25.11` input                          | 是        | 否     | 当前保留 25.11 分支并关闭 release 检查；等上游提供匹配主 `nixpkgs` 的分支后更新 |

## NixPak 使用边界

当前使用 NixPak 的应用:

- `nixpaks.firefox`
- `nixpaks.telegram-desktop`
- `nixpaks.qq`

当前未使用 NixPak 的主要图形应用:

- Zed、Cursor、VSCode、WPS Office CN、Orca
- Google Chrome、Chromium
- WeChat，它使用 `appimageTools.wrapAppImage` 和 bubblewrap 参数，不是 NixPak
- Clash Verge Rev、Noctalia Shell、Voxtype Vulkan

NixPak 适合继续用于浏览器和闭源 IM 这类需要限制家目录读写面的应用；编辑器、输入法数据、桌面 shell 和系统服务类应用不默认套 NixPak，避免破坏插件、LSP、桌面集成或系统服务行为。

## 检查命令

```bash
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.zed-editor' --impure
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.stably-orca' --impure
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.nixpaks.firefox' --impure
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.nixpaks.qq' --impure
```

## 参考

- Zed Linux 安装文档：<https://zed.dev/docs/linux>
- NixOS Wiki Zed：<https://wiki.nixos.org/wiki/Zed>
- Orca release：<https://github.com/stablyai/orca/releases/tag/v1.4.134>
