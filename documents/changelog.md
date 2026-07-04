# 变更记录

本文件作为仓库配置变更的主线索引，按时间倒序记录。具体背景、当前行为、使用方式、验证和回滚步骤应写入关联专题文档。

## 2026-07-04

### 为 Noctalia 锁屏新增专用 PAM 服务

- 影响范围：Niri/Noctalia Linux 图形桌面的锁屏密码认证路径。
- 配置入口：`modules/nixos/desktop.nix`、`home/linux/gui/base/noctalia/default.nix`。
- 变更内容：新增 `security.pam.services.noctalia-lock`，并在 `noctalia-shell.service`
  中设置 `NOCTALIA_PAM_SERVICE=noctalia-lock`，让 Noctalia 锁屏使用专用轻量 PAM 服务，而不是默认走完整
  `/etc/pam.d/login` 登录栈。
- 验证方式：执行 `nix eval` 检查 `noctalia-lock` PAM 服务存在、Noctalia 用户服务环境变量指向
  `noctalia-lock`；执行 `nixfmt --check` 和低风险 eval 测试。
- 关联文档：[Linux 桌面基础配置](../home/linux/gui/base/README.md)。

## 2026-07-03

### 安装 Zed 并记录应用版本审计

- 影响范围：`apollo`、`athena`、`generic` NixOS 桌面 Home Manager
  GUI 编辑器包列表，应用版本来源审计文档。
- 配置入口：`home/linux/gui/base/editors.nix`、`home/base/core/npm.nix`、
  `home/base/core/shells/default.nix`、`home/base/tui/dev-tools.nix`。
- 变更内容：通过主 `pkgs.zed-editor`
  安装 Zed；记录当前主要 GUI 应用的求值版本、版本来源、是否局部固定以及是否使用 NixPak；明确当前 NixPak 只封装 Firefox、Telegram
  Desktop 和 QQ，WeChat 使用 bubblewrap AppImage 封装而不是 NixPak；安装
  `bun`，将 OpenCode 从 Nix 包列表移除，改为通过用户级 npm 安装 `opencode-ai`，并记录 Pi/Oh My
  Pi 的 bun 安装方式。
- 验证方式：执行
  `nixfmt --check home/linux/gui/base/editors.nix home/base/core/npm.nix home/base/core/shells/default.nix home/base/tui/dev-tools.nix`；执行
  `nix eval` 检查 `pkgs.zed-editor`、`pkgs.bun`、`nixpaks.firefox`、`nixpaks.telegram-desktop`、
  `nixpaks.qq` 和 `bwraps.wechat` 版本；执行 Home Manager 用户包列表求值；使用 `nu -c` 检查 `cy` 和
  `oy` wrapper 可解析。
- 关联文档：[应用版本审计](./application-version-audit.md)、[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

## 2026-06-30

### 添加通用 NixOS 桌面 host

- 影响范围：x86_64 NixOS flake outputs、通用桌面部署入口、Home
  Manager 桌面配置中的个人 secret 依赖。
- 配置入口：`outputs/x86_64-linux/src/olympians-generic.nix`、`hosts/olympians-generic/`。
- 变更内容：从 `apollo` 复制出 `generic` host，保留桌面/Niri/Home Manager 基础配置；注释掉
  `secrets/nixos.nix` 和 `modules.secrets.desktop.enable`；注释掉
  `preservation.nix`；关闭 NVIDIA/force-X11 主机选项；避免通用 host 依赖 `/etc/agenix/*`
  下的个人 secret。
- 验证方式：执行 `nixfmt --check`；执行 `nix eval` 检查 `generic` 主机名、Home Manager
  home 目录、Nix extraOptions 和 preservation 选项；执行低风险 eval 测试。
- 关联文档：[通用 NixOS 桌面 Host](./generic-nixos-host.md)。

### 对齐 AeroSpace 与 Niri 工作区自动分配

- 影响范围：`artemis` macOS AeroSpace 工作区、NixOS Niri 工作区、聊天/浏览器/文档/Codex
  GUI/代码编辑器/音乐/其他工具窗口自动归类。
- 配置入口：`home/darwin/aerospace/aerospace.toml`、`home/linux/gui/niri/conf/keybindings.kdl`、
  `home/linux/gui/niri/conf/windowrules.kdl`、`home/linux/gui/niri/conf/scripts/normalize-workspaces.sh`、
  `hosts/olympians-apollo/niri-hardware.kdl`、`hosts/olympians-athena/niri-hardware.kdl`。
- 变更内容：将 `1` 定义为终端、`2` 定义为浏览器、`3` 定义为文档笔记、`4` 定义为 Codex
  GUI 类 AI 图形客户端、`5` 定义为 VSCode/Zed/Cursor 代码编辑器、`6` 定义为微信/QQ/Telegram 等聊天、
  `8` 定义为音乐、`0` 定义为 Clash Verge/CC
  Switch/Zoom 等其他工具；同步更新快捷键和显示器绑定，并新增 Niri 工作区顺序整理脚本。
- 验证方式：执行 AeroSpace TOML 静态检查、`prettier --check`、`niri validate`；运行中可用
  `aerospace list-apps`、`niri msg windows` 校准实际 app id。
- 关联文档：[AeroSpace 使用指南](./aerospace-usage.md)、[Niri 工作区与窗口分配](./niri-workspaces.md)。

### 将 Voxtype 切换到 Vulkan 版

- 影响范围：`apollo` NixOS Linux 图形桌面、Voxtype 用户服务、Whisper small 本地语音转写延迟。
- 配置入口：`home/linux/gui/base/voice-input.nix`。
- 变更内容：将 Voxtype 包从 CPU 版 `pkgs.voxtype` 切换为 `pkgs.voxtype-vulkan`；在 `voxtype.service`
  中设置 `VOXTYPE_VULKAN_DEVICE=nvidia`，让 Whisper Vulkan 后端优先选择 RTX
  3070。该调整用于修复实际测试中 2.7 秒录音在 CPU 版上需要约 34 秒转写的问题。
- 验证方式：执行 `nixfmt --check home/linux/gui/base/voice-input.nix`；执行
  `nix eval .#nixosConfigurations.apollo.pkgs.voxtype-vulkan.version --raw`；执行
  `nix build .#nixosConfigurations.apollo.pkgs.voxtype-vulkan --no-link --print-out-paths`。
- 关联文档：[Linux Voxtype 语音输入](./linux-voice-input.md)。

## 2026-06-29

### 重新生成 homelab 专用 SSH 密钥

- 影响范围：`ssh-key-romantic.age`、内网 `192.168.*` SSH 登录私钥、目标 homelab 主机授权列表。
- 配置入口：私有仓库
  `/home/vitus/my-secrets/ssh-key-romantic.age`、`documents/homelab-ssh-key-romantic.md`、
  `flake.lock` 的 `mysecrets` input。
- 变更内容：重新生成全新的 Ed25519 `ssh-key-romantic` keypair，将私钥按 `secrets.nix`
  recipients 加密进 private secrets 仓库；更新文档中的 public
  key 和 SHA256 指纹。目标主机仍需单独把新 public key 加入 `authorized_keys`。
- 验证方式：只检查解密后的私钥字节数和派生出的 public key/fingerprint；确认私钥为 432 字节。
- 关联文档：[Homelab SSH Key `ssh-key-romantic`](./homelab-ssh-key-romantic.md)。

### 恢复被空明文覆盖的 agenix secrets

- 影响范围：`mysecrets` flake input、NixOS desktop agenix secrets、TOTP 配置、GitHub token、Nix
  access token、work alias secret。
- 配置入口：`flake.lock`、私有仓库 `/home/vitus/my-secrets`、`secrets/README.md`。
- 变更内容：在 `my-secrets` 中从 `f1ed2a6` 恢复四个非空 secret，并按当前 recipients 重新加密；将
  `mysecrets` input 更新到包含该修复的后续提交；记录 `agenix -r`
  在非交互空 stdin 下会写入空明文的风险。
- 验证方式：只检查解密后字节数，不输出明文；确认 `alias-for-work.nushell.age` 为 5058 字节、
  `github_token.age` 为 41 字节、`nix-access-tokens.age` 为 68 字节、`totp-secrets.conf.age`
  为 121 字节。
- 关联文档：[Secrets 管理](../secrets/README.md)。

### 记录本机 private secrets 仓库位置

- 影响范围：secrets 管理文档、`mysecrets` flake input 排查流程。
- 配置入口：`secrets/README.md`、`flake.nix` 的 `mysecrets` input。
- 变更内容：记录本机 private secrets 仓库路径 `/home/vitus/my-secrets`、远端
  `https://github.com/Vitus213/my-secrets.git`，以及修改 private secrets 后需要提交推送并执行
  `nix flake update mysecrets`。
- 验证方式：静态检查 `/home/vitus/my-secrets` 的 git 状态、远端和最近提交；未读取 secret 明文。
- 关联文档：[Secrets 管理](../secrets/README.md)。

### 恢复 homelab 专用 SSH 密钥 `ssh-key-romantic`

- 影响范围：`apollo` 的 agenix desktop secrets、Home Manager SSH 配置、内网 `192.168.*`
  SSH 登录路径。
- 配置入口：`secrets/nixos.nix`、`home/base/tui/ssh.nix`、私有仓库 `my-secrets/secrets.nix`。
- 变更内容：在 `my-secrets` 中新增 `ssh-key-romantic.age`；恢复 NixOS 将其解密到
  `/etc/agenix/ssh-key-romantic` 的映射；保留 `192.168.*` 使用这把专用 key；同时让 Home
  Manager 激活后把 `~/.ssh/config` 转为用户自有的 `0600` 普通文件，避免 OpenSSH 拒绝读取 Nix store
  symlink。
- 验证方式：执行 `nixfmt --check secrets/nixos.nix home/base/tui/ssh.nix`；执行 `nix eval` 检查
  `ssh-key-romantic` secret 文件和 `/etc/agenix/ssh-key-romantic` 目标权限；对已有 `.age`
  文件做解密内容哈希对比，确认 rekey 未改变明文。
- 关联文档：[Homelab SSH Key `ssh-key-romantic`](./homelab-ssh-key-romantic.md)。

## 2026-06-28

### 启用 Voxtype 语音输入

- 影响范围：`apollo` NixOS Linux 图形桌面、Home Manager 用户包、Voxtype 用户服务、Niri 快捷键。
- 配置入口：`home/linux/gui/base/voice-input.nix`、`home/linux/gui/niri/conf/keybindings.kdl`。
- 变更内容：安装 Voxtype `0.7.2`、`wtype`、`wl-clipboard`、`libnotify` 和 `playerctl`；新增
  `voxtype.service` 用户服务；关闭 Voxtype 内置热键和 OSD，由 Niri 的 `Mod+Shift+Space`
  切换录音、`Mod+Ctrl+Shift+Space` 取消录音或转写；配置 Whisper `small` 中文模型，优先通过 `wtype`
  输入文本并在失败时回退到剪贴板；模型文件保留为用户首次使用时手动下载，不写入 Git 或 Nix store。
- 验证方式：执行 `nixfmt --check home/linux/gui/base/voice-input.nix`；执行
  `nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.systemd.user.services.voxtype.Service.ExecStart --json --show-trace`；执行
  `nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace`；集成前已用
  `voxtype setup check`、本地 daemon 和 wav 样本转写验证 Voxtype、`wtype`、`wl-copy`
  与 OSD 关闭行为。
- 关联文档：[Linux Voxtype 语音输入](./linux-voice-input.md)。

### 调整 apollo 的 2K 显示器缩放

- 影响范围：`apollo` 主机 Niri 输出配置、2K 主显示器 `DP-1` 的桌面缩放。
- 配置入口：`hosts/olympians-apollo/niri-hardware.kdl`。
- 变更内容：将 `DP-1` 的 Niri `scale` 从 `1` 调整为
  `1.24`，接近同一显示器在 Windows 上使用的 124% 缩放观感；保持 `2560x1440@200.000` 显示模式不变。
- 验证方式：执行 `niri validate`；执行 `niri msg outputs` 检查 `DP-1` 显示约 `Scale: 1.24`。
- 关联文档：[Niri 显示缩放](./niri-display-scaling.md)。

### 添加 Nushell AI Agent 全权限快捷命令

- 影响范围：Home Manager TUI 工具包、Nushell 启动配置。
- 配置入口：`home/base/tui/dev-tools.nix`、`home/base/tui/shell/default.nix`。
- 变更内容：安装 `opencode`；新增 `cy` 作为 Codex 全权限快捷命令；新增 `oy`
  作为 OpenCode 全权限快捷命令。
- 验证方式：执行 `nixfmt --check home/base/tui/dev-tools.nix home/base/tui/shell/default.nix`；使用
  `nu -c` 检查 `cy` alias 和 `oy` 包装命令可解析。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

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

### 安装 CC Switch 并固定到 AeroSpace 0Other 工作区

- 影响范围：`artemis` macOS Homebrew 应用列表、AeroSpace 窗口自动分配、AeroSpace 使用文档。
- 配置入口：`modules/darwin/apps.nix`、`home/darwin/aerospace/aerospace.toml`。
- 变更内容：通过 Homebrew cask 安装 `cc-switch`；将 `com.ccswitch.desktop` 自动移动到
  `0Other`，也就是 `Option + 0`
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
