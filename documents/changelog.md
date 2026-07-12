# 变更记录

本文件作为仓库配置变更的主线索引，按时间倒序记录。具体背景、当前行为、使用方式、验证和回滚步骤应写入关联专题文档。

## 2026-07-12

### 恢复 Esc 与 Caps Lock 原生键位

- 影响范围：全部 NixOS 桌面主机和 macOS Artemis；`Esc` 恢复 Escape，`Caps Lock`
  恢复系统大写锁定，不再交换两个键，也不再提供点按 Escape、长按 Control 的复合行为。
- 配置入口：`modules/nixos/desktop/peripherals.nix`、`modules/darwin/system.nix`。
- 变更内容：移除 Linux 上仅用于 Esc/Caps Lock 映射的 `keyd 2.6.0` 服务配置；移除 macOS 的
  nix-darwin `system.keyboard` 映射。Fcitx5/Rime 继续禁止 Caps Lock 参与中西文切换，不改变其系统键位。
- 验证方式：求值确认 Apollo、Athena 和 Generic 的 `services.keyd.enable` 均为 `false`；确认
  Artemis 的 `system.keyboard.enableKeyMapping` 为 `false` 且 `userKeyMapping` 为空。未执行
  `just local`、`nixos-rebuild switch` 或 `darwin-rebuild switch`，实体键行为需部署后实测。
- 关联文档：[Esc 与 Caps Lock 原生键位](./keyboard-layout.md)、[Fcitx5 与 Rime 小鹤双拼](./fcitx5-rime-input-method.md)。

### 将桌面壁纸切换为本机 WLOP 作品

- 影响范围：全部 Linux GUI 主机的 Noctalia 壁纸目录；每台主机需要单独准备不受 Git 管理的本机图片。
- 配置入口：`home/linux/gui/base/noctalia/config/settings.json`、
  `home/linux/gui/base/noctalia/default.nix`、`flake.nix`、`flake.lock`。
- 变更内容：从 WLOP 官方 ArtStation 筛选 8 张横屏展示图，仅保存到本机 `~/Pictures/WLOP`；Noctalia 改为
  递归扫描该目录。移除 `wallpapers` flake input 和 Home Manager 的只读壁纸目录映射；公开仓库
  [Vitus213/wallpapers](https://github.com/Vitus213/wallpapers) 删除旧图片，改为只记录 WLOP 官方作品页、
  本机文件名和分辨率，并忽略所有图片/视频文件，避免公开再分发未授权原图。
- 验证方式：确认 8 张本机文件均为可识别 JPEG，分辨率覆盖 `1920x753` 至 `1920x1126`；确认
  `noctalia-shell.service` 为 `active`，通过 IPC 将所有显示器切换到 `dome.jpg`，运行时缓存记录
  `DP-1` 已使用该文件；执行 `nix eval .#evalTests --show-trace --print-build-logs --verbose` 返回 `true`，
  `nixfmt --check` 通过。未执行 `just local`。
- 关联文档：[Linux 桌面基础配置](../home/linux/gui/base/README.md)、
  [WLOP 壁纸来源清单](https://github.com/Vitus213/wallpapers)。

## 2026-07-11

### 向 Orca FHS 环境映射 agenix secrets

- 影响范围：StablyAI Orca `1.4.134` 及其内置终端；Orca 可以读取 `/etc/agenix`
  中所有由当前用户权限允许读取的 secrets。
- 配置入口：`overlays/stably-orca/default.nix`。
- 变更内容：为 `appimageTools.wrapAppImage` 增加 `/etc/agenix` 目录级只读
  `--ro-bind-try`，让 Orca 的 `buildFHSEnv` 在重建 `/etc`
  后仍能按宿主机相同路径访问 agenix 文件；目录级挂载同时避免单文件目标的父目录不存在时被 Bubblewrap 静默跳过。未提供该目录的主机继续正常启动。
- 验证方式：构建
  `apollo.pkgs.stably-orca`；确认生成的 Bubblewrap 启动器包含目录级只读挂载；通过宿主机 user
  systemd 启动同参数 FHS 环境，确认 `/etc/agenix` 可见，并由 Nushell 成功执行
  `source /etc/agenix/alias-for-work.nushell`。部署后对比新旧 Orca mount namespace，确认新终端存在
  `/persistent/etc/agenix -> /etc/agenix` 只读挂载；结束部署前遗留的旧 Orca 后，报错终端随之退出。
- 关联文档：[Orca 桌面应用](./orca.md)。

### 修复 Fcitx5 启动竞争和 WeChat 候选框

- 影响范围：全部 Linux GUI 主机的 Fcitx5 启动方式，以及 WeChat `4.1.1.4`
  在 Niri/XWayland 下的 Rime 候选框。
- 配置入口：`home/linux/gui/base/fcitx5/default.nix`、`hardening/bwraps/wechat.nix`。
- 变更内容：增加用户级 `org.fcitx.Fcitx5.desktop` 并设置 `Hidden=true`，禁用系统 XDG
  autostart 生成的过早启动实例，只保留 Home Manager `fcitx5-daemon.service`；WeChat 沙箱继续隐藏
  `WAYLAND_DISPLAY` 并显式使用 XIM，确保 XWayland 客户端连接到已注册的 Fcitx5 XIM 服务。
- 验证方式：复现到旧实例缺少 `XIM_SERVERS`，且 Home
  Manager 服务因 D-Bus 名称冲突退出；当前会话停止旧实例并启动 `fcitx5-daemon.service` 后，确认服务为
  `active`、
  `XIM_SERVERS(ATOM) = @server=fcitx`、Rime 正常；重启 WeChat 后实测候选框恢复显示。求值确认
  `Hidden=true` 覆盖，`apollo` 和 `athena` 的 `system.build.toplevel` 均构建成功。
- 关联文档：[Fcitx5 与 Rime 小鹤双拼](./fcitx5-rime-input-method.md)、[Linux 微信与 QQ](./linux-im-apps.md)。

### 安装 Linux 腾讯会议、持久化用户数据并固定工作区

- 影响范围：全部 Linux GUI 主机新增腾讯会议 `3.26.10.401`，并将其窗口自动分配到 Niri
  `0other`；Apollo 和 Athena 保留登录态与应用数据，不持久化可重建缓存。
- 配置入口：`home/linux/gui/base/media.nix`、`home/linux/gui/niri/conf/windowrules.kdl`、
  `hosts/olympians-apollo/preservation.nix`、`hosts/olympians-athena/preservation.nix`。
- 变更内容：通过主 `nixpkgs` 的 `pkgs.wemeet`
  安装腾讯会议，沿用上游包提供的 Wayland 屏幕共享、摄像头预览、X11 输入焦点和音频设备兼容修复；按实测
  `app-id="wemeetapp"` 将主窗口和辅助窗口送到 `0other`；持久化 `~/.local/share/wemeetapp`，不持久化
  `~/.cache/wemeetapp`。
- 验证方式：求值确认 Apollo Home Manager 包列表包含 `wemeet 3.26.10.401`；构建 `apollo.pkgs.wemeet`
  成功；以隔离的临时 `HOME` 启动客户端，确认程序能启动，并确认持久数据和缓存分别写入
  `$XDG_DATA_HOME/wemeetapp` 与 `$XDG_CACHE_HOME/wemeetapp`；执行 `niri validate` 成功；从 `6chat`
  启动后，实测主窗口、辅助窗口和音频接入方式窗口均匹配 `wemeetapp` 并进入 `0other`。未执行
  `just local` 或
  `nixos-rebuild switch`，登录、音视频、中文输入和 Niri/Wayland 屏幕共享仍需部署后实测。
- 关联文档：[Linux 腾讯会议](./tencent-meeting.md)、[Niri 工作区与窗口分配](./niri-workspaces.md)。

### 将 Orca 内置终端默认 shell 切换为 Nushell

- 影响范围：Linux 图形桌面的 StablyAI Orca `1.4.134`
  内置终端；不改变系统登录 shell、Ghostty 启动链路或其他应用的 `SHELL`。
- 配置入口：`overlays/stably-orca/default.nix`。
- 变更内容：使用 `makeWrapper` 为 Orca 启动包装器设置 Nix store 中的 Nushell 路径，使新建终端默认以
  `nu -l` 启动；部署后需要在 Orca 的 Terminal 设置中重启长期运行的 terminal daemon。
- 验证方式：构建 `apollo.pkgs.stably-orca`；检查生成的 `bin/orca` 包装器包含
  `export SHELL=...-nushell-0.113.1/bin/nu`；使用同一 store 路径执行 `nu -l` 并确认版本为
  `0.113.1`；求值确认 `apollo` Home Manager 仍安装 Orca。未执行 `just local` 或
  `nixos-rebuild switch`，因为这些命令会切换当前系统。
- 关联文档：[Orca 桌面应用](./orca.md)。

## 2026-07-10

### 切换聊天应用自启动并修复 WeChat 候选框

- 影响范围：全部 Linux GUI 主机的 XDG autostart，以及 WeChat `4.1.1.4`
  在 Niri/XWayland 下的 Fcitx5/Rime 候选框显示。
- 配置入口：`home/linux/gui/base/xdg/autostart.nix`、`hardening/bwraps/wechat.nix`。
- 变更内容：移除 Telegram 的默认自启动条目，改为登录后启动 WeChat；保留新版 WeChat，通过在其 bubblewrap 沙箱中移除
  `WAYLAND_DISPLAY` 并显式设置 `XMODIFIERS=@im=fcitx`，强制使用 XWayland/XIM，避免 Fcitx
  Portal 候选框坐标在 Niri 下落到屏幕外。
- 验证方式：求值确认 autostart 列表包含 `wechat.desktop`
  且不含 Telegram；构建 WeChat 包并检查生成的包装脚本包含 XIM 环境参数；`apollo` 和 `athena` 的
  `system.build.toplevel` 均构建成功。未执行 `just local` 或
  `nixos-rebuild switch`，因此候选框仍需部署后进行实际输入确认。
- 关联文档：[Linux 微信与 QQ](./linux-im-apps.md)。

### 统一 Voxtype 简体输出并简化录音快捷键

- 影响范围：Linux 图形桌面的 Voxtype 中文转写结果和 Niri 录音快捷键。
- 配置入口：`home/linux/gui/base/voice-input.nix`、`home/linux/gui/niri/conf/keybindings.kdl`。
- 变更内容：将 Whisper 初始提示词改为简体中文，并通过 OpenCC `1.3.0` 的 `t2s`
  本地后处理确保最终输出为简体；将录音切换键从 `Mod+Shift+Space` 改为单键 `Scroll Lock`，取消键改为
  `Shift+Scroll Lock`。
- 验证方式：执行 `nixfmt --check` 和
  `niri validate`；实际调用 OpenCC 验证繁体转简体；求值检查生成的 Voxtype TOML；构建 `apollo` 的
  `system.build.toplevel` 成功。未执行 `just local` 或
  `nixos-rebuild switch`，因为这些命令会切换当前系统。
- 关联文档：[Linux Voxtype 语音输入](./linux-voice-input.md)。

### 安装 StablyAI Orca 桌面应用

- 影响范围：Linux 图形桌面 Home Manager 与 Niri 配置，新增可从应用启动器或 `orca`
  命令启动的 Orca 桌面应用；窗口默认打开到 `5code` 工作区并最大化。
- 配置入口：`home/linux/gui/base/misc.nix`、`overlays/stably-orca/default.nix`、
  `home/linux/gui/niri/conf/windowrules.kdl`。
- 变更内容：新增 `pkgs.stably-orca` overlay，固定官方 `v1.4.134` Linux
  AppImage；保持安装后的主命令为 `orca`，同时避免与 nixpkgs 中 GNOME 屏幕阅读器 `pkgs.orca`
  属性冲突；Niri 按 `app-id="orca"` 将窗口放入 `5code` 工作区并最大化。
- 验证方式：执行 `nix build` 构建 `apollo.pkgs.stably-orca`；求值确认版本为
  `1.4.134`；检查生成的桌面文件包含 `Exec=orca %U` 和 `StartupWMClass=orca`；执行 `niri validate`
  确认窗口规则有效；构建 `apollo` 的 `system.build.toplevel` 成功。未执行 `just local` 或
  `nixos-rebuild switch`，因为这些命令会切换当前系统。
- 关联文档：[Orca 桌面应用](./orca.md)、[应用版本审计](./application-version-audit.md)、[Linux 桌面基础配置](../home/linux/gui/base/README.md)。

### 切换 OMP 到 GPT 5.6 模型

- 影响范围：用户级 OMP 配置、`llm-codex`
  自定义模型 catalog，以及 OMP 的默认、慢速、计划、advisor、review 和 smol 模型角色。
- 配置入口：`~/.omp/agent/models.yml`、`~/.omp/agent/config.yml`。
- 变更内容：将 OMP 从 `omp/16.3.5` 更新到 `omp/16.4.0`；在 `llm-codex` provider 下新增 `gpt-5.6-sol`
  和 `gpt-5.6-terra`，两者按输入上下文 `370K`、输出上限 `128K` 配置；将 `smol` 切到
  `llm-codex/gpt-5.6-sol:high`，`default`、`advisor`、`review` 切到
  `llm-codex/gpt-5.6-sol:xhigh`，`slow`、`plan` 保留 `llm-codex/gpt-5.6-terra:xhigh`。
- 验证方式：执行 `omp models llm-codex` 确认两个 5.6 模型显示为 `370K` context 和 `128K`
  max-out；分别用
  `omp --model llm-codex/gpt-5.6-sol --thinking low --no-tools --no-session -p "只输出 OK"` 和
  `omp --model llm-codex/gpt-5.6-terra --thinking low --no-tools --no-session -p "只输出 OK"`
  确认请求成功。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

## 2026-07-05

### 消除 apollo rebuild 的 Home Manager 与 flake input warning

- 影响范围：`apollo` 主机构建求值、共享 Home Manager shell/SSH/Catppuccin 配置，以及 Linux
  gaming 模块的 AAGL 输入检查。
- 配置入口：`home/base/core/theme.nix`、`home/base/core/core.nix`、`home/base/tui/ssh.nix`、`modules/nixos/desktop/gaming.nix`。
- 变更内容：显式设置 `catppuccin.autoEnable = true` 以匹配当前全局启用行为；为 Catppuccin VSCode
  port 覆盖 pnpm 构建参数到 `nodejs-slim`；保留 Atuin 占用 Ctrl-R 并关闭 fzf history widget；将 Home
  Manager SSH 配置从已废弃的 `programs.ssh.matchBlocks` 迁移到 `programs.ssh.settings`；保留当前
  `aagl-gtk-on-nix release-25.11` 输入并在模块顶层关闭 release 分支检查。
- 验证方式：执行 `nixfmt`；执行
  `nix eval .#nixosConfigurations.apollo.config.system.build.toplevel.drvPath --show-trace`
  确认目标 evaluation warning 不再出现；求值确认 fzf
  Ctrl-R 命令为空、`catppuccin.autoEnable = true`、AAGL release 检查为 `false`、`192.168.*` SSH
  Host 规则已由 `programs.ssh.settings` 生成。
- 关联文档：[应用版本审计](./application-version-audit.md)、[Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)、[Homelab SSH Key `ssh-key-romantic`](./homelab-ssh-key-romantic.md)。

## 2026-07-04

### 让 apollo 双系统硬件时钟跟随 Windows 本地时间

- 影响范围：`apollo` 主机的 NixOS 与 Windows 双系统时间同步行为。
- 配置入口：`hosts/olympians-apollo/default.nix`。
- 变更内容：启用
  `time.hardwareClockInLocalTime = true`，让 NixOS 按 Windows 默认方式把 RTC 视为本地时间，避免双系统切换后时间偏移。
- 验证方式：执行低风险 eval 测试；未执行 `just local` 或
  `nixos-rebuild switch`，因为这些命令会切换当前系统。
- 关联文档：[rEFInd 双系统启动](./refind-boot.md)。

### 临时覆盖 Bun 到 1.3.14

- 影响范围：所有复用共享 overlays 的 NixOS 和 nix-darwin 配置中的 `pkgs.bun`，以及通过 Bun 安装的 Pi
  / Oh My Pi CLI。
- 配置入口：`overlays/bun/default.nix`、`home/base/core/npm.nix`。
- 变更内容：新增 Bun overlay，将 `pkgs.bun` 从当前主 `nixpkgs` 的 `1.3.13` 临时覆盖到
  `1.3.14`，以满足最新版 `@oh-my-pi/pi-coding-agent` 的 `bun >= 1.3.14`
  要求；同步更新应用版本审计和 Nushell AI
  Agent 快捷命令文档。待 nixpkgs 合入并进入当前输入后应移除该 overlay。
- 验证方式：先新增 Bun 版本 eval test 并确认旧配置失败；修改后执行 `nixfmt --check`、Bun 版本求值、
  `nix eval .#evalTests --show-trace --print-build-logs`、
  `nix build .#nixosConfigurations.apollo.pkgs.bun --no-link --print-build-logs`，并用构建出的 Bun
  `1.3.14` 安装最新版 `@oh-my-pi/pi-coding-agent` 后确认 `omp --version` 返回 `omp/16.3.5`。
- 关联文档：[应用版本审计](./application-version-audit.md)、[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

### 修复 Nushell 直接启动时找不到 omp

- 影响范围：所有复用共享 Home Manager shell 配置的 Nushell 启动环境，以及 Bun 全局安装的 `omp`。
- 配置入口：`home/base/core/shells/config.nu`、`home/base/core/shells/default.nix`。
- 变更内容：在 Nushell 自身配置中直接加入 `~/.bun/bin` 和
  `~/.cache/.bun/bin`，避免 Nushell 未经 Bash 启动时丢失 Bun global bin；同步修正文档中 PATH 说明。
- 验证方式：先新增 Nushell Bun PATH eval test 并确认旧配置失败；修改后执行
  `nixfmt --check`、低风险 eval 测试，并用
  `nu --config home/base/core/shells/config.nu --env-config /dev/null -c` 检查 `$env.PATH` 能找到
  `~/.cache/.bun/bin/omp`。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

### 修复 Bun 全局 bin 未进入 Nushell PATH

- 影响范围：所有复用共享 Home Manager shell 配置的 Bash/Nushell 启动环境，以及通过 Bun 安装的 Pi /
  Oh My Pi CLI。
- 配置入口：`home/base/core/shells/default.nix`。
- 变更内容：在已有 `~/.bun/bin` 之外，将 Bun 当前提示的 global bin 目录 `~/.cache/.bun/bin`
  也加入 PATH，使 `omp` 这类 Bun 全局命令能被 Nushell 继承；同步更新 Nushell AI Agent 快捷命令文档。
- 验证方式：先求值确认旧 `bashrcExtra` 只包含 `~/.bun/bin`，且本机 `omp` 位于
  `~/.cache/.bun/bin/omp`；修改后执行 `nixfmt --check` 并重新求值确认 `bashrcExtra` 包含
  `~/.cache/.bun/bin`。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

### 同步全仓 README 与专题文档当前事实

- 影响范围：仓库 README、outputs/hosts/infra/nixos-installer
  README、Niri 缩放文档、NixOS 内核策略文档。
- 配置入口：`README.md`、`outputs/README.md`、`hosts/README.md`、`infra/README.md`、
  `nixos-installer/README.md`、`documents/niri-display-scaling.md`、`documents/nixos-kernel.md`。
- 变更内容：按当前 flake
  outputs 和求值结果更新 README 中的 NixOS 版本、主机状态、文档索引；同步 outputs 目录树中的
  `generic` 和 `empty.nix`；移除 hosts/infra 文档中不属于当前仓库的 `ryan4yin/*` 外部维护描述；标清
  `nixos-installer/` 是旧版辅助入口；将 Niri/NixOS/内核版本更新为当前求值结果，并记录
  `linuxPackages_7_0` 当前为 `7.0.14` 且上游已 EOL。
- 验证方式：执行当前 flake 的 NixOS、Niri、内核和 rEFInd 关键属性求值；执行全仓 Markdown 旧归属链接搜索、相对链接检查和
  `git diff --check`。未运行 `just local` 或 `nixos-rebuild switch`，因为本次只改文档。
- 关联文档：[NixOS 内核策略](./nixos-kernel.md)、[Niri 显示缩放](./niri-display-scaling.md)、
  [Flake 输出](../outputs/README.md)、[主机配置](../hosts/README.md)。

### 完善 README 与全新 NixOS preservation 部署教程

- 影响范围：仓库 README 入口、全新 NixOS 机器部署 NixCoffee 的操作流程、preservation 与 agenix
  bootstrap 排障文档。
- 配置入口：`README.md`、`documents/fresh-nixos-preservation-deploy.md`。
- 变更内容：将 README 标题、badge 和仓库链接改为 `Vitus213/nix-config`；新增当前仓库架构、主要 flake
  output、NixOS 新机最快部署流程；补充 fresh deploy 文档中的版本依据、`/persistent`
  检查、`~/nix-config` 被 preservation bind 成空目录时的修复方式，以及 private `mysecrets`
  拉取失败的 bootstrap 处理。
- 验证方式：执行静态链接/旧仓库引用搜索；执行 README 和 fresh deploy 文档的关键命令片段检查。未运行
  `just local` 或 `nixos-rebuild switch`，因为本次只改文档且这些命令会切换当前系统。
- 关联文档：[全新 NixOS + preservation 部署流程](./fresh-nixos-preservation-deploy.md)。

### 回退 Noctalia 锁屏轻量 PAM 与 Niri spawn-at-startup 尝试

- 影响范围：Niri/Noctalia Linux 图形桌面的 shell 启动顺序和锁屏认证环境。
- 配置入口：`home/linux/gui/niri/default.nix`、`home/linux/gui/niri/conf/config.kdl`、
  `home/linux/gui/base/noctalia/default.nix`、`modules/nixos/desktop.nix`。
- 变更内容：撤回 Noctalia 专用 `noctalia-lock` PAM 服务和 Niri `spawn-at-startup`
  启动方式；恢复 Home Manager `noctalia-shell.service` 用户服务启动 Noctalia，并取消
  `NOCTALIA_PAM_SERVICE` 环境变量，使锁屏认证回到默认完整 `/etc/pam.d/login`
  PAM 栈。该回退用于恢复登录/锁屏界面稳定性，后续另行排查快速解锁方案。
- 验证方式：执行 `nixfmt --check`、低风险 eval 测试、`niri validate`，并求值检查
  `noctalia-shell.service` 存在、服务环境不包含 `NOCTALIA_PAM_SERVICE`、`noctalia-lock`
  PAM 服务不存在。
- 关联文档：[Linux 桌面基础配置](../home/linux/gui/base/README.md)。

### 禁用无实际 Btrfs 布局的 btrbk 实例

- 影响范围：所有导入 NixOS base 模块的主机，尤其是当前使用 ext4 persistence 的 `apollo`。
- 配置入口：`modules/nixos/base/btrbk.nix`。
- 变更内容：注释掉共享模块中无条件启用的 `services.btrbk.instances.btrbk`，仅保留
  `/btr_pool/@persistent` Btrfs 快照模板；当前 `apollo` 的 `/persistent`
  是 ext4 根分区内的持久化目录，不存在 `/btr_pool` 或 `/snapshots`，因此不应启动 btrbk。
- 验证方式：执行 `nix eval` 确认 `apollo.config.services.btrbk.instances` 为空；执行 `nix eval` 和
  `findmnt` 确认 `apollo` 当前文件系统为 ext4/vfat；执行 `nixfmt --check` 和低风险 eval 测试。
- 关联文档：[btrbk 配置状态](./btrbk.md)。

### 修复 Nushell fzf 集成遮蔽 parse 导致的启动失败

- 影响范围：所有复用共享 Home Manager
  shell 配置的 Nushell 启动链路，以及依赖 Nushell 自动启动的 Zellij 会话。
- 配置入口：`home/base/tui/shell/default.nix`、`home/base/core/core.nix`、`home/base/tui/zellij/default.nix`。
- 变更内容：将 `nu_scripts` 的 `modules/argx` 从星号导入改为限定名导入，避免其自定义 `parse`
  覆盖 Nushell 内建 `parse`；保留 Kubernetes 模块通过 `argx parse` 使用该辅助命令，修复 Home
  Manager 生成的 fzf Nushell 集成脚本执行 `parse --regex` 时失败的问题。
- 验证方式：先用 `use modules/argx *` 复现 `parse --regex` unknown flag；再执行限定名导入的低风险
  `nu -n -c` 验证 fzf 集成脚本和 `argx parse` 可同时使用；执行 `nixfmt --check` 和低风险 eval 测试。
- 关联文档：[Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)。

### 调整 Niri/Noctalia 空闲熄屏时间

- 影响范围：Linux 图形桌面的 `hypridle` 空闲管理行为。
- 配置入口：`home/linux/gui/base/hypridle/hypridle.conf`。
- 变更内容：将显示器 DPMS 关闭动作从空闲 30 分钟提前到空闲 20 分 30 秒；锁屏仍在空闲 20 分钟触发，熄屏保留 Noctalia
  10 秒锁屏倒计时后的缓冲。
- 验证方式：执行 `niri msg action --help` 确认 `power-off-monitors`/`power-on-monitors`
  动作存在；执行 `journalctl --user -u hypridle.service`
  确认当前服务已注册锁屏和熄屏 listener；执行格式检查和低风险 eval 测试。
- 关联文档：[Linux 桌面基础配置](../home/linux/gui/base/README.md)。

### 修复 croc source hash drift 导致的 apollo build 失败

- 影响范围：所有导入共享 overlays 的 NixOS 和 nix-darwin 配置中的 `pkgs.croc`。
- 配置入口：`overlays/croc/default.nix`、`modules/base/packages.nix`。
- 变更内容：新增 croc overlay，将 `croc 10.4.5` 的 `src.rev` 固定到当前 `v10.4.5` tag 指向的 commit
  `57e5fd7cef0466e3dbe086e18d00fc9e40e4dffa`，并修正 GitHub archive hash，避免 fixed-output
  derivation hash mismatch 中断 `apollo` toplevel build。
- 验证方式：执行
  `nix build .#nixosConfigurations.apollo.pkgs.croc --no-link --print-build-logs`；执行
  `nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace --print-build-logs`。
- 关联文档：[Croc build 修复](./croc-build-fix.md)。

### 收敛 Linux 软件包来源到主 unstable

- 影响范围：Linux 桌面 GUI 编辑器、Rust 工具链、Clash Verge、Guix、QQ
  NixPak 封装、flake 输入结构和应用版本审计文档。
- 配置入口：`flake.nix`、`outputs/default.nix`、`home/linux/gui/base/editors.nix`、
  `home/base/tui/editors/packages.nix`、`modules/nixos/desktop/networking/clash-verge.nix`、
  `modules/nixos/desktop/guix.nix`、`hardening/nixpaks/default.nix`。
- 变更内容：移除直接维护的 `nixpkgs-stable`、`nixpkgs-2505` 和 `nixpkgs-master`
  inputs；将 Cursor、VSCode、WPS Office CN、Rust 工具链、Clash Verge Rev、Guix 和 QQ 封装切回主
  `pkgs`，也就是主 `nixpkgs` 的 `nixos-unstable` 包集合；保留 `nixpkgs-patched` 作为已有的 patched
  unstable 来源。
- 验证方式：执行 `bash scripts/check-nixpkgs-policy.sh`；执行
  `nix eval .#evalTests --show-trace --print-build-logs --verbose`；执行 `nix eval` 检查
  `pkgs.bun`、`pkgs.code-cursor`、`pkgs.vscode`、`pkgs.wpsoffice-cn` 和 `pkgs.clash-verge-rev`
  版本。尝试执行 `nix flake update` 和分批更新核心 inputs，但当前网络到 GitHub archive 多次返回
  `Truncated tar archive`，因此本次只完成输入结构收敛和删除无用 lock 节点，未完成全量刷新到最新远端 rev。
- 关联文档：[应用版本审计](./application-version-audit.md)、[Linux 微信与 QQ](./linux-im-apps.md)。

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
