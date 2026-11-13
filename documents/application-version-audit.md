# 应用版本审计

本文件记录仓库中用户会直接启动的主要应用版本来源、当前求值版本、是否局部固定、是否使用 NixPak。普通 CLI 工具和系统基础包通常跟随对应
`nixpkgs` 输入统一更新，不在这里逐项列出。

## 当前结论

- Zed 已通过 `home/linux/gui/base/editors.nix` 安装，使用主 `pkgs.zed-editor`，当前求值版本为
  `1.6.3`。
- 当前 NixPak 只封装 2 个应用：`nixpaks.telegram-desktop`、`nixpaks.qq`。
- 明确局部固定、局部修补或不完全跟随主 `nixpkgs` 统一更新的用户可见应用/数据包括 Pi / Oh My
  Pi、QQ、WeChat、飞书、Delta、Dux Files、Rime Ice、Catppuccin VSCode 扩展。
- Linux 桌面常规应用默认跟随主 `nixpkgs` 输入，也就是
  `github:nixos/nixpkgs/nixos-unstable`；仓库不再为常规软件额外维护 `nixpkgs-stable` 或
  `nixpkgs-master` 包集合。

## 应用清单

| 应用                   | 当前版本                    | 配置入口                                                                                    | 版本来源                                                                                                                   | 固定/修补        | NixPak | 处理建议                                                                                                                                                                                                   |
| ---------------------- | --------------------------- | ------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ---------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Zed                    | `1.6.3`                     | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.zed-editor`                                                                                          | 否               | 否     | 跟随主 `nixpkgs` 更新                                                                                                                                                                                      |
| Delta                  | `0.23.0`                    | `flake.nix`、`overlays/delta/default.nix`、`home/linux/gui/base/editors.nix`                | 官方 `zed-industries/delta-nix` flake input，固定于 `flake.lock`                                                           | 是               | 否     | `nix flake update delta` 更新；CLI 改名 `delta-zed` 避免与 git-delta 冲突；详见 [Delta](./delta.md)                                                                                                        |
| Cursor                 | `3.7.19`                    | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.code-cursor`                                                                                         | 否               | 否     | 跟随主 `nixpkgs` 更新                                                                                                                                                                                      |
| VSCode                 | `1.125.0`                   | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.vscode`                                                                                              | 否               | 否     | 跟随主 `nixpkgs` 更新                                                                                                                                                                                      |
| Catppuccin VSCode 扩展 | `3.19.0`                    | `home/base/core/theme.nix`                                                                  | `catppuccin/nix` 的 VSCode port，本仓库修正 pnpm `nodejs-slim` 参数                                                        | 是               | 否     | 等上游改用 `nodejs-slim` 后移除本地包覆盖                                                                                                                                                                  |
| LibreOffice            | `26.8.0.3`                  | `home/linux/gui/base/editors.nix`                                                           | 主 `nixpkgs` 的 `pkgs.libreoffice`（上游取消 fresh/still 双线，`libreoffice-fresh` 已改为告警别名）                        | 否               | 否     | 跟随主 `nixpkgs` 更新                                                                                                                                                                                      |
| Zen Browser            | `1.23.4b`                   | `flake.nix`、`home/linux/gui/base/browsers.nix`                                             | 社区 flake `youwen5/zen-browser-flake`（每日自动跟随上游），固定于 `flake.lock`                                            | 是               | 否     | `nix flake lock --update-input zen-browser` 更新；详见 [Zen Browser](./zen-browser.md)                                                                                                                     |
| Telegram Desktop       | `6.8.2`                     | `home/linux/gui/base/misc.nix`、`hardening/nixpaks/telegram-desktop.nix`                    | 主 `nixpkgs` 的 `pkgs.telegram-desktop`                                                                                    | 否               | 是     | 保留 NixPak 沙箱，版本跟随主 `nixpkgs`                                                                                                                                                                     |
| QQ                     | `3.2.29-2026-05-28`         | `home/linux/gui/base/misc.nix`、`hardening/nixpaks/default.nix`、`hardening/nixpaks/qq.nix` | 局部固定官方 QQ deb                                                                                                        | 是               | 是     | 后续更新需改 URL/hash 并同步 `linux-im-apps.md`                                                                                                                                                            |
| WeChat                 | `4.1.13.26`                 | `home/linux/gui/base/misc.nix`、`overlays/wechat/`                                          | 固定官方 Linux DEB；局部回移上游配方，依赖仍用主 `nixpkgs`                                                                 | 是               | 否     | 直接运行，无沙箱/路径隔离；原生 Wayland + text-input-v3，详见 `linux-im-apps.md`                                                                                                                           |
| 飞书                   | `7.66.10`                   | `home/linux/gui/base/misc.nix`                                                              | 主 `nixpkgs` 的 `pkgs.feishu`                                                                                              | 是（捕获参数）   | 否     | 保持 XWayland；`WebRTCPipeWireCapturer` 强制屏幕共享走 portal/PipeWire                                                                                                                                     |
| Rime Ice               | `2026-06-21-3ec476e`        | `overlays/fcitx5/default.nix`                                                               | 固定 GitHub rev                                                                                                            | 是               | 否     | 更新词库时改 rev/hash 并同步 Fcitx5 文档                                                                                                                                                                   |
| OpenCode               | 用户级 npm                  | `home/base/core/npm.nix`、`home/base/tui/shell/default.nix`                                 | `npm install -g opencode-ai@latest`                                                                                        | 否               | 否     | 跟随 npm 更新，不通过 Nix 固定                                                                                                                                                                             |
| Pi / Oh My Pi          | 用户级 bun                  | `~/.bun/bin` 或 `~/.cache/.bun/bin`（PATH 见 `home/base/core/shells/`）、`~/.omp/agent/`    | `bun install -g @oh-my-pi/pi-coding-agent`                                                                                 | 否               | 否     | `bun update -g @oh-my-pi/pi-coding-agent` 更新，不通过 Nix 固定；运行时 `bun` 由 `home/base/core/npm.nix` 安装；`config.yml` 用户级，`models.yml` 由 nix-config 模板生成（软链，key 经 my-secrets/agenix） |
| bb                     | 用户级 npm                  | `documents/bb.md`                                                                           | `npm install -g bb-app@latest`                                                                                             | 否               | 否     | 跟随 npm 更新，不通过 Nix 固定                                                                                                                                                                             |
| FlClash                | `0.8.96`                    | `modules/nixos/desktop/networking/flclash.nix`                                              | 官方 GitHub release AppImage（本地打包；macOS 手动 dmg）                                                                   | 是               | 否     | 更新需改 `flclash.nix` 中 URL/hash；详见 [应用版本审计](./application-version-audit.md)                                                                                                                    |
| Guix                   | `1.5.0`                     | `modules/nixos/desktop/guix.nix`                                                            | 主 `nixpkgs` 的 `pkgs.guix`                                                                                                | 否               | 否     | 跟随主 `nixpkgs` 更新                                                                                                                                                                                      |
| Noctalia Shell         | `5.5.0`（apollo 已 switch） | `flake.nix`、`overlays/noctalia/`、`home/linux/gui/base/noctalia/`                          | 官方独立 input 固定 `c2573248…`，保留上游自己的 nixpkgs                                                                    | 是（PAM/工作区） | 否     | 仅维护两个 C++ 补丁；部署与验收边界见 [Noctalia v5](./noctalia-v5.md)                                                                                                                                      |
| Dux Files              | `2.1.2`                     | `flake.nix`、`modules/nixos/desktop/file-manager.nix`、`home/linux/gui/base/xdg/mime.nix`   | 官方 `duxlabs-dev/dux-files` 的 `v2.1.2`；依赖跟随主 `nixpkgs`                                                             | 是               | 否     | 替代 Dolphin/Thunar/Ark，目录默认用 Dux，终端 Yazi 保留；详见 [文件管理器](./niri-workspaces.md#文件管理器dux-files)                                                                                       |
| Voiceless              | `0.1.0`                     | `flake.nix`、`home/linux/gui/base/voice-input.nix`                                          | `github:Vitus213/voiceless` flake input 的 CPU 版（云端 ASR，本地推理未启用）                                              | 是               | 否     | `nix flake lock --update-input voiceless` 更新；详见 [Linux 语音输入](./linux-voice-input.md)                                                                                                              |
| Sioyek                 | `2.0.0-unstable`            | `home/linux/gui/base/media.nix`、`home/linux/gui/base/xdg/mime.nix`                         | 主 `nixpkgs` 的 `pkgs.sioyek` 经同名 wrapper 强制 `QT_QPA_PLATFORM=xcb`（Qt6 wayland + NVIDIA EGL 不兼容），PDF 默认查看器 | 否               | 否     | 跟随主 `nixpkgs` 更新；Qt 修好 wayland EGL 后可移除 wrapper                                                                                                                                                |

## Google Cloud CLI

共享 TUI 配置 `home/base/tui/dev-tools.nix` 通过 `home.packages` 安装 `pkgs.google-cloud-sdk`，提供
`gcloud`、`bq` 和 `gsutil`。Linux 跟随主 `nixpkgs`，macOS 跟随
`nixpkgs-darwin`；Linux 当前求值版本为 `583.0.0`，不单独固定版本或启用额外组件。

部署后运行 `gcloud version` 检查安装；需要访问云资源时再执行
`gcloud auth login`。安装不自动登录，凭据留在用户配置目录，不写入 Nix 仓库。更新走对应 nixpkgs
input；移除时删除该包声明并重新部署。

### eric-kvm-dev SSH 连接

`home/base/tui/ssh.nix` 声明 `eric-kvm-dev` 别名，通过 Google IAP 连接 `10.99.0.2:22`，远端用户为
`vitus`，只使用本机 `~/.ssh/id_ed25519`。对应公钥必须已加入远端用户的 `authorized_keys`。

```bash
gcloud auth login vitus.zhang@polygala.ai
ssh eric-kvm-dev
```

隧道显式指定 `boxlite-dev-project`、`us-east5`、`kvm-dev` 网络和 `eric-kvm-dev-ssh`
目标组，因此不需要设置默认 project。Nix 配置中的 `ProxyCommand`
使用同一包集合的 gcloud 绝对路径。部署后可用 `ssh -G eric-kvm-dev` 检查 `proxycommand` 和
`identityfile`；仅手改 `~/.ssh/config` 会在下次 Home Manager 激活时被覆盖。移除别名时删除对应
`programs.ssh.settings` 项并重新部署。

## NixPak 使用边界

当前使用 NixPak 的应用:

- `nixpaks.telegram-desktop`
- `nixpaks.qq`

当前未使用 NixPak 的主要图形应用:

- Zed、Cursor、VSCode、LibreOffice Fresh、Delta、飞书
- Zen Browser
- WeChat，它使用局部固定的 Linux DEB 配方直接运行，不使用 NixPak、bubblewrap 或 FHS 沙箱
- FlClash、Noctalia Shell、Voiceless

NixPak 适合继续用于闭源 IM 这类需要限制家目录读写面的应用；编辑器、浏览器、输入法数据、桌面 shell 和系统服务类应用不默认套 NixPak，避免破坏插件、LSP、桌面集成或系统服务行为。

## 检查命令

```bash
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.zed-editor' --impure
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); pkgs = flake.nixosConfigurations.apollo.pkgs; in pkgs.lib.getVersion pkgs.nixpaks.qq' --impure
```

## 参考

- Zed Linux 安装文档：<https://zed.dev/docs/linux>
- NixOS Wiki Zed：<https://wiki.nixos.org/wiki/Zed>
