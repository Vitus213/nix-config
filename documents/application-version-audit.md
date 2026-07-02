# 应用版本审计

本文件记录仓库中用户会直接启动的主要应用版本来源、当前求值版本、是否局部固定、是否使用 NixPak。普通 CLI 工具和系统基础包通常跟随对应
`nixpkgs` 输入统一更新，不在这里逐项列出。

## 当前结论

- Zed 已通过 `home/linux/gui/base/editors.nix` 安装，使用主 `pkgs.zed-editor`，当前求值版本为
  `1.6.3`。
- 当前 NixPak 只封装 3 个应用：`nixpaks.firefox`、`nixpaks.telegram-desktop`、`nixpaks.qq`。
- 明确局部固定、不完全跟随 `nixpkgs` 统一更新的应用/数据目前有 3 个：QQ、WeChat、Rime Ice。
- `pkgs-master` 当前锁定在 2026-03-25，适合临时拿较新的 Cursor、VSCode、Guix、Clash
  Verge；但不能假设它对所有包都更新。例如锁定的 `pkgs-master.zed-editor` 是 `0.228.0`，比主
  `pkgs.zed-editor` 的 `1.6.3` 旧。

## 应用清单

| 应用             | 当前版本             | 配置入口                                                                                    | 版本来源                                                          | 固定 | NixPak | 处理建议                                        |
| ---------------- | -------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- | ---- | ------ | ----------------------------------------------- |
| Zed              | `1.6.3`              | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.zed-editor`                                 | 否   | 否     | 跟随主 `nixpkgs` 更新                           |
| Cursor           | `2.6.21`             | `home/linux/gui/base/editors.nix`                                                           | `nixpkgs-master` 的 `pkgs-master.code-cursor`                     | 否   | 否     | 更新 `nixpkgs-master` 时同步检查                |
| VSCode           | `1.112.0`            | `home/linux/gui/base/editors.nix`                                                           | `nixpkgs-master` 的 `pkgs-master.vscode`                          | 否   | 否     | 更新 `nixpkgs-master` 时同步检查                |
| WPS Office CN    | `12.1.2.23578`       | `home/linux/gui/base/editors.nix`                                                           | `nixpkgs-stable` 的 `pkgs-stable.wpsoffice-cn`                    | 否   | 否     | 跟随 `nixpkgs-stable` 更新                      |
| Firefox          | `152.0`              | `home/linux/gui/base/browsers.nix`、`hardening/nixpaks/firefox.nix`                         | 主 `nixpkgs` 的 `pkgs.firefox`                                    | 否   | 是     | 保留 NixPak 沙箱，版本跟随主 `nixpkgs`          |
| Google Chrome    | `149.0.7827.114`     | `home/linux/gui/base/browsers.nix`                                                          | 主 `nixpkgs` 的 `pkgs.google-chrome`                              | 否   | 否     | 跟随主 `nixpkgs` 更新                           |
| Chromium         | `149.0.7827.114`     | `home/linux/gui/base/browsers.nix`                                                          | aarch64 fallback，主 `nixpkgs` 的 `pkgs.chromium`                 | 否   | 否     | 跟随主 `nixpkgs` 更新                           |
| Telegram Desktop | `6.8.2`              | `home/linux/gui/base/misc.nix`、`hardening/nixpaks/telegram-desktop.nix`                    | 主 `nixpkgs` 的 `pkgs.telegram-desktop`                           | 否   | 是     | 保留 NixPak 沙箱，版本跟随主 `nixpkgs`          |
| QQ               | `3.2.29-2026-05-28`  | `home/linux/gui/base/misc.nix`、`hardening/nixpaks/default.nix`、`hardening/nixpaks/qq.nix` | 局部固定官方 QQ deb                                               | 是   | 是     | 后续更新需改 URL/hash 并同步 `linux-im-apps.md` |
| WeChat           | `4.1.1.4`            | `home/linux/gui/base/misc.nix`、`hardening/bwraps/wechat.nix`                               | 局部固定官方 AppImage                                             | 是   | 否     | 后续更新需改 URL/hash 并同步 `linux-im-apps.md` |
| Rime Ice         | `2026-06-21-3ec476e` | `overlays/fcitx5/default.nix`                                                               | 固定 GitHub rev                                                   | 是   | 否     | 更新词库时改 rev/hash 并同步 Fcitx5 文档        |
| Bun              | `1.3.13`             | `home/base/core/npm.nix`                                                                    | 主 `nixpkgs` 的 `pkgs.bun`                                        | 否   | 否     | 由 Nix 安装，用于用户级安装 Pi / Oh My Pi       |
| OpenCode         | 用户级 npm           | `home/base/core/npm.nix`、`home/base/tui/shell/default.nix`                                 | `npm install -g opencode-ai@latest`                               | 否   | 否     | 跟随 npm 更新，不通过 Nix 固定                  |
| Pi / Oh My Pi    | 用户级 bun           | `home/base/core/npm.nix`、`documents/nushell-ai-agent-aliases.md`                           | `bun install -g @oh-my-pi/pi-coding-agent@latest oh-my-pi@latest` | 否   | 否     | 跟随 bun 更新，不通过 Nix 固定                  |
| Clash Verge Rev  | `2.4.7`              | `modules/nixos/desktop/networking/clash-verge.nix`                                          | `nixpkgs-master` 的 `pkgs-master.clash-verge-rev`                 | 否   | 否     | 等主 `nixpkgs` 修复后可评估回退到主 `pkgs`      |
| Guix             | `1.5.0`              | `modules/nixos/desktop/guix.nix`                                                            | `nixpkgs-master` 的 `pkgs-master.guix`                            | 否   | 否     | 等主 `nixpkgs` 修复后可评估回退到主 `pkgs`      |
| Noctalia Shell   | `4.4.3`              | `home/linux/gui/base/noctalia/default.nix`                                                  | `nixpkgs-patched` 的 `pkgs-patched.noctalia-shell`                | 否   | 否     | 跟随 `nixpkgs-patched` 更新                     |
| Voxtype Vulkan   | `0.7.2`              | `home/linux/gui/base/voice-input.nix`                                                       | 主 `nixpkgs` 的 `pkgs.voxtype-vulkan`                             | 否   | 否     | 跟随主 `nixpkgs` 更新                           |

## NixPak 使用边界

当前使用 NixPak 的应用:

- `nixpaks.firefox`
- `nixpaks.telegram-desktop`
- `nixpaks.qq`

当前未使用 NixPak 的主要图形应用:

- Zed、Cursor、VSCode、WPS Office CN
- Google Chrome、Chromium
- WeChat，它使用 `appimageTools.wrapAppImage` 和 bubblewrap 参数，不是 NixPak
- Clash Verge Rev、Noctalia Shell、Voxtype Vulkan

NixPak 适合继续用于浏览器和闭源 IM 这类需要限制家目录读写面的应用；编辑器、输入法数据、桌面 shell 和系统服务类应用不默认套 NixPak，避免破坏插件、LSP、桌面集成或系统服务行为。

## 检查命令

```bash
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.zed-editor' --impure
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.nixpaks.firefox' --impure
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.nixpaks.qq' --impure
```

## 参考

- Zed Linux 安装文档：<https://zed.dev/docs/linux>
- NixOS Wiki Zed：<https://wiki.nixos.org/wiki/Zed>
