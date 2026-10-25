# 变更记录

本文件作为仓库配置变更的主线索引，按时间倒序记录。具体背景、当前行为、使用方式、验证和回滚步骤应写入关联专题文档。

## 2026-10-26

### Noctalia 系统监控 Disk 显示 0 GB

- 影响范围：Linux 桌面 Noctalia 顶栏 SystemMonitor 与系统监控面板的 Disk 行。保存即热加载，无需部署。
- 配置入口：`home/linux/gui/base/noctalia/config/settings.json`（两处 `diskPath`）。
- 变更内容：`diskPath` 从 `/persistent` 改为 `/`；`/persistent` 在 apollo 上不是挂载点，`df`
  无对应行导致显示 0。
- 验证方式：JSON 校验通过；顶栏磁盘读数变为 `297G`，与 `df /` 一致。
- 关联文档：[Noctalia 系统监控磁盘路径](./noctalia-system-monitor.md)。

### Noctalia 工作区 urgent 红色角标不消失

- 影响范围：Linux 桌面（niri + Noctalia）顶栏工作区指示器。需 `just local` 后
  `systemctl --user restart noctalia-shell`。
- 配置入口：`overlays/noctalia-shell/default.nix`。
- 变更内容：noctalia-qs 0.0.12 不处理 niri 的
  `WorkspaceUrgencyChanged`，urgent 清除后仍显示红色；overlay 给 `NiriService.qml` 加
  `onRawEvent`，收到该事件时 `Niri.refreshWorkspaces()`。
- 验证方式：patched noctalia-shell 构建通过，home-manager 服务 `ExecStart`
  指向新包；`niri msg -j event-stream` 实测 foot 响铃触发 `WorkspaceUrgencyChanged`
  true/false；`just test`；`just local` 后截图确认 urgent 清除时顶栏角标随之变灰。
- 关联文档：[Noctalia 工作区红色角标](./noctalia-workspace-urgent.md)。

## 2026-10-25

### Herdr 通知改为桌面通知（`delivery = "system"`）

- 影响范围：Linux 与 macOS 共用的
  `~/.config/herdr/config.toml`。Agent 完成或需要输入时改为桌面通知（Linux 走 `notify-send` →
  noctalia），不再是只在 Herdr 界面内可见的 toast；foot 切到后台时也能看到。
- 配置入口：`home/base/tui/dev-tools.nix` 的 `home.activation.herdrConfig`。
- 变更内容：原配置基于“本机无通知守护进程”选了 `herdr`，现 noctalia 已提供通知服务；`terminal`
  模式不识别 foot，因此选 `system`。部署后执行 `herdr server reload-config`。
- 验证方式：`notify-send --app-name Herdr` 实测弹出；`just test`。
- 关联文档：[Herdr](./herdr.md) 的“通知与 Agent 集成”。

### Linux 主终端切回 foot：快捷键对调，登录只自启 foot

- 影响范围：Linux 桌面（niri）。`Mod+Return` 改为 `footclient`（复用常驻的
  `foot.service`），`Mod+Shift+Return` 改为 alacritty；XDG autostart 移除
  `Alacritty.desktop`，登录只打开一个 foot 窗口。快捷键文件是 out-of-store
  symlink，保存即由 niri 热重载；自启需 `just local`，下次登录生效。
- 配置入口：`home/linux/gui/niri/conf/keybindings.kdl`、`home/linux/gui/base/xdg/autostart.nix`。
- 变更内容：终端说明一直写的是“foot 主终端（`Mod+Return`）、alacritty 备用”，但快捷键实际相反且两个终端都自启，现按说明对齐。
- 验证方式：`niri validate` 通过、niri 已重载；`just test`；切换后 `~/.config/autostart/` 下不再有
  `Alacritty.desktop`。
- 关联文档：[终端说明](../home/base/gui/terminal/README.md)。

## 2026-10-22

### Herdr server 改为 systemd 用户服务

- 影响范围：Linux 主机的 herdr 后台 server。需
  `just local`，并按文档手动迁移一次（会结束当前所有 pane 进程）。
- 配置入口：`home/base/tui/dev-tools.nix`（`systemd.user.services.herdr`）。
- 变更内容：server 原先挂在首次启动它的终端所属 cgroup 下（apollo 上是
  `app-Alacritty@autostart.service`），那个 unit 一停就会连带结束所有 agent。现在改为独立服务：随 graphical-session 启动，已有 server 时跳过，`Restart=always`，HM 切换时不重启。
- 验证方式：activationPackage 构建通过；`systemd-analyze --user verify` 通过；`ExecCondition`
  在已有 server 时返回 1（跳过），无 server 时返回 0。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)。

### Herdr：auto-title 插件、Claude/OMP 集成、foot 去标题栏

- 影响范围：foot 不再自绘标题栏（所有 Linux 主机）；Herdr 新建 tab 不再弹命名框；apollo 用户级安装 auto-title 插件与 claude/omp 集成。foot 与 Herdr 配置需
  `just local`，foot 还需重启 `foot.service`。
- 配置入口：`home/base/gui/terminal/terminals.nix`（`csd.preferred`）、`home/base/tui/dev-tools.nix`（`prompt_new_tab_name`）。
- 变更内容：标题栏文字 `apollo: nix-config` 来自 Herdr 默认的
  `ui.window_title`，这一点保留；niri 未开
  `prefer-no-csd`，foot 会自绘一条标题栏，现在只关掉 foot 的。tab 名改由 auto-title 按会话或目录/分支生成。
- 验证方式：home-manager activationPackage 构建通过，`foot.ini` 含
  `[csd] preferred=none`；`herdr tab list` 显示自动命名；`herdr integration status` 显示 claude
  v11、omp v10 为 current。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)、[终端说明](../home/base/gui/terminal/README.md)。

### Herdr 侧边栏改用 herdr-radar 插件，config.toml 改为可写

- 影响范围：所有主机的 `~/.config/herdr/config.toml` 从 Home
  Manager 只读 symlink 改为激活时生成的可写文件；新增 radar 快捷键 `prefix+a`、`prefix+,`，显式设置
  `[theme] name = "catppuccin"`。需 `just local` 后手动安装插件。
- 配置入口：`home/base/tui/dev-tools.nix`（`herdrBaseConfig`、`home.activation.herdrConfig`）。
- 变更内容：内置 Agents 面板只用圆点区分状态、`done` 很快变回
  `idle`；herdr-radar 用颜色和标记区分 working / blocked / done /
  idle，done 保持到看过为止。插件会改写
  `config.toml`，所以激活时用 Nix 基础内容加上旧文件中 radar 的托管块重新生成该文件。
- 验证方式：home-manager activationPackage 构建通过；在沙箱中用 radar 自身的
  `managed-config.apply()` 写入托管块，再跑激活片段合并，`tomllib`
  解析通过、结果与插件直写的结构一致；apollo `just local` 后安装 radar
  `1.4.9`（`3e72fe2`），`configure` 输出 `theme (dark)`，`herdr agent list` 各 pane 均带 radar
  token。
- 手动步骤：`herdr plugin install hhdebb/herdr-radar`，然后
  `herdr plugin action invoke hhdebb.herdr-radar.configure` 和 `…state-start`。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)。

### 清理构建告警：home-manager 升级、LibreOffice 别名、光标显式启用

- 影响范围：所有主机的 home-manager 模块（apollo 实际闭包差异仅 fzf
  Nushell 集成方式与 HM 文档）；apollo 的 LibreOffice 包名。需 `just local` 生效。
- 配置入口：`flake.lock`（`home-manager` `b885baa` 2026-07-04 → `ab97a5d`
  2026-10-21）、`home/linux/gui/base/editors.nix`、`home/linux/gui/base/gtk.nix`。
- 变更内容：
  - 旧 home-manager 的 `modules/systemd.nix` 使用
    `pkgs.stdenv.isLinux`，触发 nixpkgs 弃用告警；上游已改为
    `hostPlatform`，因此升级 home-manager 输入。
  - `libreoffice-fresh` 改为 `libreoffice`：nixpkgs
    2026-08-11 起前者只是告警别名，两者是同一个 drv（26.8.0.3）。
  - 新 home-manager 要求 `home.pointerCursor.enable = true` 显式开启；补上后系统闭包不变。
  - `/root/.nix-defexpr/channels`、`/nix/var/nix/profiles/per-user/root/channels`
    是 26.05 安装镜像遗留的 channel，仓库已
    `nix.channel.enable = false`，但 nixpkgs 不会自动清理，需要手动删除一次（见下方说明）。
- 验证方式：`just test` 通过；apollo toplevel 构建无 evaluation warning；hestia / generic /
  hermes 求值无告警；`nix store diff-closures`
  确认仅 fzf 集成与 HM 文档变化，Ctrl-R 仍由 Atuin 负责。
- 手动步骤：`sudo rm -f /nix/var/nix/profiles/per-user/root/channels /nix/var/nix/profiles/per-user/root/channels-1-link && sudo rm -rf /root/.nix-defexpr/channels`。
- 关联文档：[Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)、[应用版本审计](./application-version-audit.md)。

### profile 卡片统一 gruvbox 主题与 15px 圆角

- 影响范围：`Vitus213/Vitus213` README 四张卡；`agent-usage-report` 输出的卡片配色与圆角，需
  `just local` 后定时任务才按新配色刷新。
- 配置入口：`home/base/tui/agent-usage/agent_usage.py`（`--theme`、`--radius`、`THEMES`）、`home/base/tui/agent-usage/default.nix`。
- 变更内容：脚本支持 github-readme-stats 的 9 个主题和自定义圆角，当前使用
  `gruvbox`、15px。README 中 stats 与 streak 都改成 437×220 再缩放到 400，修正第一行高度差，圆角写 16.4 以抵消缩放。
- 验证方式：新脚本推送成功；按 README 实际 URL 抓取四张卡并缩放到 400 宽拼图，第一行两张均为 400×202，第二行两张均为 400×190。
- 关联文档：[AI Agent 用量统计与 WakaTime](./agent-usage.md)。

### profile README：语言卡与 AI agent 用量卡并排

- 影响范围：`Vitus213/Vitus213` README 第二行；`agent-usage-report` 额外输出两张 400×190 卡片，需
  `just local` 后定时任务才会刷新它们。
- 配置入口：`home/base/tui/agent-usage/agent_usage.py`（`render_compact`）。
- 变更内容：新增 `agent-usage-compact.svg`、`agent-time-compact.svg`。README 中 top-langs 改为
  `tokyonight`、宽 400，与有额度紧凑卡并排；810 宽完整版保留在分支上。
- 验证方式：本地渲染后与 top-langs 拼图核对尺寸和背景；推送后 README 中除 komarev 访问计数（第三方服务当前 404）外，其余图片均返回 200。
- 关联文档：[AI Agent 用量统计与 WakaTime](./agent-usage.md)。

### AI agent 用量卡片与 WakaTime 接入

- 影响范围：所有启用 `home/base` 的主机（新增 `agent-usage-report`
  与每小时定时任务、`ccusage`、`wakatime-api-key`）；启用 `modules.secrets` 的 NixOS /
  darwin 主机新增 `wakatime-api-key` secret。需 `just local` 生效。
- 配置入口：`home/base/tui/agent-usage/`、`overlays/ccusage/`、`secrets/nixos.nix`、`secrets/darwin.nix`、`flake.lock`
  （`mysecrets` → `ce0ed1b`，新增 `wakatime-api-key.age`）。
- 变更内容：统计 Claude Code / Codex /
  omp 的活跃时长、token 与按 LiteLLM 标价折算的成本，每小时推送到 `Vitus213/Vitus213` 的
  `agent-usage` 分支，并渲染有额度、无额度两张卡片；`ccusage`
  固定为 20.0.39（nixpkgs 的 20.0.17 多算 Codex token）；WakaTime key 改由 agenix 提供，通过
  `api_key_vault_cmd` 读取。profile README 改为 810 全宽布局，并删除每天 403 的 `Waka Readme`
  workflow。本机手动安装 `claude-code-wakatime` 插件，并把 `cleanupPeriodDays` 改为 3650。
- 验证方式：`just test` 通过；`apollo` toplevel 构建通过，`hestia` / `generic` / `hermes`
  求值通过；`artemis` 的 launchd agent、secret 路径和 `ccusage`
  drv 求值通过（完整 toplevel 因既有 catppuccin IFD 无法在 Linux 求值）。实际运行
  `agent-usage-report` 推送成功，omp token 总数与 `ccusage pi` 一致，Codex 与 ccusage 20.0.39 一致。
- 关联文档：[AI Agent 用量统计与 WakaTime](./agent-usage.md)。

## 2026-10-21

### Voiceless 升级到 0417c78：`stream` 复用 daemon 的本地模型

- 影响范围：apollo 的 `voiceless` 包与 `voiceless.service`；switch 后服务重启生效。
- 配置入口：`flake.lock`（`voiceless` input `e48eec0` →
  `0417c78`）；`home/linux/gui/base/voice-input.nix` 未改。
- 变更内容：包含 `156f6a4`（`doctor` 不再在 tokio 线程上 panic）与 `0417c78`（daemon 运行时
  `voiceless stream` 通过新 D-Bus 方法 `StartSession`
  交给 daemon 执行，不再二次加载 GPU 模型导致 CUDA OOM）。
- 验证方式：voiceless 仓库 `just test`（155 通过）/ `just lint` 通过；本地构建的 CUDA 包以假
  `pw-record` 回放历史录音，委托识别、`--no-inject`、两次 Ctrl-C 取消（130）、忙碌拒绝、`--backend`
  独立运行、无 daemon 独立运行均通过，显存始终只有一份模型；switch 后见关联文档复验。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### SSH 客户端：局域网追加 id_ed25519，修正 apollo / artemis 地址

- 影响范围：启用 `modules.ssh.homelab` 的主机（apollo 等）生成的 `~/.ssh/config`；rebuild 后生效。
- 配置入口：`home/base/tui/ssh.nix`。
- 变更内容：`Host 192.168.*` 在 `ssh-key-romantic` 之后追加
  `~/.ssh/id_ed25519`（artemis 等局域网电脑只授权 `mainSshAuthorizedKeys`，此前 `IdentitiesOnly`
  只给 romantic 导致 `Permission denied`）；`Host apollo` `100.108.175.44` →
  `100.64.0.89`，`Host artemis` `100.83.91.107` → `100.64.0.14`（headscale 当前地址）。
- 验证方式：构建 `home.file.".ssh/config".source`，以 `ssh -F` 实测 `vitus@192.168.100.159`（返回
  `artemis`）与 `root@192.168.100.1` 免密登录成功；`ssh artemis` 因 artemis Tailscale 离线超时。
- 关联文档：[Homelab SSH Key](./homelab-ssh-key-romantic.md)。

## 2026-10-20

### 恢复 artemis 入站 SSH 的系统默认配置

- 影响范围：artemis 的 SSH 入站连接；保持 TCP 22、现有密码与公钥认证策略不变。
- 配置入口：本机 `/usr/share/openssh/default-configuration.tar.bz2`；恢复
  `/etc/ssh/sshd_config`、`sshd_config.d/100-macos.conf`、`crypto.conf`、`crypto/` 两份策略文件及
  `moduli`，共六个缺失目标。
- 变更内容：选择性恢复 Apple 默认服务端文件，不覆盖现有 Nix
  SSH 文件，不重新生成主机密钥，不修改客户端配置、防火墙或代理；本机直接生效，未执行 rebuild 或重启服务。
- 验证方式：实际系统 `sshd -t`、`sshd -T` 通过；回环地址及 apollo 到 artemis 的真实密码登录均返回
  `vitus`、`artemis`，退出码为 0；六个现有 Nix SSH 文件与四组主机公钥恢复前后校验和一致。
- 关联文档：[macOS 入站 SSH](./darwin-ssh.md)。

### apollo 登录后自启动 Slack

- 影响范围：开启 `modules.desktop.workApps` 的主机（apollo）；rebuild 后下次登录生效。
- 配置入口：`home/linux/gui/base/work-apps.nix`（`xdg.autostart.entries` 加入 `slack.desktop`）。
- 验证方式：`nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.xdg.autostart.entries`
  包含 `slack-4.51.180/share/applications/slack.desktop`。未执行 rebuild。
- 关联文档：[浏览器与工作协作应用](./work-apps.md)。

### Voiceless 重构：GPU 识别、常驻 daemon、输入框内预编辑、ScrollLock 按住说话

- 影响范围：apollo；rebuild 后需重新登录一次（input 组生效）。
- 配置入口：`home/linux/gui/base/voice-input.nix`（改用 voiceless 自带 Home Manager 模块：
  `programs.voiceless` 的 CUDA 包、`service.enable`、`overlay.enable`；fcitx5 桥接 0.2）、
  `modules/nixos/base/user-group.nix`（用户加入 `input` 组）、
  `home/linux/gui/niri/conf/keybindings.kdl`（去掉 Scroll_Lock 绑定，新增应急 `Mod+Shift+D` →
  `voiceless ctl toggle`）。
- 变更内容：Qwen3-ASR 1.7B 在 RTX
  3070 上本地识别（8 秒语音约 0.2 秒）；daemon 常驻显存，快捷键到开始录音约 15–70
  ms；识别中的文字以预编辑显示在输入框，说完由 fcitx5 上屏；ScrollLock 由 daemon 读 evdev，按住说话 / 短按切换，Ctrl+ScrollLock 为整理模式；录音时暂停媒体播放。旧的
  `~/.config/eww` 浮层与 `eww-voiceless-overlay` 服务已不再使用（浮层改为
  `~/.config/eww-voiceless`）。
- 验证方式：`nix build .#nixosConfigurations.apollo.config.home-manager.users.vitus.home.activationPackage`
  构建通过，其中 voiceless 为 2a73053 的 CUDA 构建（含 `ctl`、cublas 依赖）。未执行 rebuild。
- 手动步骤：rebuild 后运行收尾脚本（迁移历史录音路径、删除兼容符号链接、把配置切到 `local-offline` +
  `inject.prefer = "fcitx5"` +
  `[hotkey] key = "KEY_SCROLLLOCK"`、重启 fcitx5 与 daemon），再重新登录。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### 语音输入 Syllune 更名为 Voiceless，新增 Fcitx5 桥接上屏

- 影响范围：apollo；rebuild 后生效。
- 配置入口：`flake.nix`（input `voiceless` → `github:Vitus213/voiceless`，`nixpkgs-voiceless`）、
  `home/linux/gui/base/voice-input.nix`（`voiceless-cpu`、`voiceless-web`、`eww-voiceless-overlay`）、
  `home/linux/gui/niri/conf/keybindings.kdl`（`voiceless-overlay-toggle`）。
- 变更内容：上游仓库与二进制更名；数据目录迁到 `~/.config/voiceless`、`~/.local/share/voiceless`、
  `~/.cache/voiceless`，旧路径暂留符号链接。rebuild 后需手动把 `~/.config/eww/syllune-overlay*`
  改名为 `voiceless-overlay*`、删除旧符号链接和 `~/.config/systemd/user/syllune-web.service.d`。
- 同时新增 Fcitx5 桥接模块：`voice-input.nix` 把 `voiceless-fcitx5-bridge`（用本机 pkgs 构建）加入
  `i18n.inputMethod.fcitx5.addons`；rebuild 并重启 fcitx5 后，把 `~/.config/voiceless/config.toml`
  的 `inject.prefer` 改为 `"fcitx5"`，文本经输入法直接上屏，剪贴板仅作兜底。
- 验证方式：`nix build .#nixosConfigurations.apollo.config.system.build.toplevel --dry-run`
  求值通过；构建出的 `fcitx5-with-addons-5.1.23`
  已包含桥接模块，并在私有 D-Bus 会话中通过端到端提交测试。未执行 rebuild。
- 网页控制台：daemon 在 http://127.0.0.1:8790/
  提供七页控制台（实时、识别引擎、词库、模式与提示词、快捷键与上屏、历史、诊断），原 `voiceless-web`
  服务（`history serve`）已删除，避免端口冲突。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### 清理 ANTHROPIC_* / CLAUDE_CODE_* 环境变量与中转通道；Herdr 升级到 0.9.5

- 影响范围：所有 source `alias-for-work.nushell` 的主机（apollo / artemis / hermes）；更新
  `mysecrets` 并 rebuild 后新开 shell 生效。
- 配置入口：`my-secrets/alias-for-work.nushell.age`：删除
  `ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_BASE_URL`、`ANTHROPIC_API_KEY`、
  `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`、`CLAUDE_CODE_ATTRIBUTION_HEADER`，以及 anyrouter /
  agentrouter / glm / claude 四个中转通道的 token、base URL 和 `use-any` / `use-agent` / `use-glm` /
  `use-claude` 切换函数。
- 变更内容：这些变量让 Claude Code 提示 "claude.ai connectors are disabled because ANTHROPIC_API_KEY
  ... is set"，清理后 Claude Code 只使用 claude.ai 登录。Herdr 通过官方脚本重装为
  `0.9.5`（`~/.local/bin`，不由仓库管理）。
- 验证方式：用 `master_key` 解密新密文，确认已没有
  `ANTHROPIC|CLAUDE_|ANYROUTER|AGENT_|GLM_|use-`；recipients 与原密文一致（8 个）；
  `herdr --version` 为 `0.9.5`。未执行 rebuild。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)、[Herdr Agent 终端运行时](./herdr.md)。

### NixOS 主机解密 omp-keys，自动生成 omp models.yml

- 影响范围：开启 `modules.secrets.desktop` 的 NixOS 主机（apollo）；rebuild 后
  `~/.omp/agent/models.yml` 由模板重新生成。
- 配置入口：`secrets/nixos.nix`（新增 `age.secrets."omp-keys"`，与 darwin 一致）。
- 变更内容：此前只有 `secrets/darwin.nix` 声明了 `omp-keys`，apollo 的 home-manager 激活时找不到
  `/run/agenix/omp-keys` 而跳过生成，本机一直用 8 月的手写 `models.yml`。旧文件已备份为
  `~/.omp/agent/models.yml.bak-20261020-manual`。用户级 `config.yml` 的角色、`enabledModels`
  与 fallback 同步改为模板 provider（default `openai/gpt-5.6-sol`，slow/plan
  `deepseek/deepseek-v4-pro`，advisor/review `anthropic/claude-opus-5-5`，smol
  `deepseek/deepseek-flash`），旧版备份为 `config.yml.bak-20261020-manual`。
- 验证方式：`just test` 通过；`age.secrets.omp-keys.path` 求值为 `/run/agenix/omp-keys`，owner 为
  `vitus`。未执行 rebuild。
- 关联文档：[omp 模型配置](./omp-models.md)、[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

### 修复 Alt+Space 无法唤起 Noctalia launcher

- 影响范围：Linux 桌面（Niri + Noctalia）；rebuild 后需执行
  `systemctl --user restart noctalia-shell`。
- 配置入口：`home/linux/gui/base/noctalia/default.nix`（服务 `QT_QPA_PLATFORM` 由 `wayland;xcb` 改为
  `wayland`）。
- 变更内容：noctalia-qs 0.0.12 的 ipc 按 `QT_QPA_PLATFORM`
  推导的 display 过滤实例，服务与会话取值不一致导致 `noctalia-shell ipc call ...` 报
  `No running instances`，Alt+Space 等快捷键失效。
- 验证方式：`just test`；运行中实测 `QT_QPA_PLATFORM=wayland` 时 `noctalia-shell list`
  为空，与服务一致时可找到实例。未执行 rebuild。
- 关联文档：[Noctalia IPC 与服务环境](./noctalia-ipc.md)。

### 恢复 bun，修复 omp 命令丢失

- 影响范围：所有主机的用户环境；rebuild 后需手动执行一次
  `bun install -g @oh-my-pi/pi-coding-agent`。
- 配置入口：`home/base/core/npm.nix`（`home.packages` 加回 `bun`）。
- 变更内容：8 月迁到 omp flake 时移除了 `bun`，10 月删除 omp
  input 改回 bun 全局安装时没有加回，导致 generation 56 之后 `omp` 消失（`~/.cache/.bun/bin`
  为空，且缺少 `bun` 运行时）。
- 验证方式：`just test` 通过；`home-manager.users.vitus.home.packages` 含 `bun`。未执行 rebuild。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

### 平台判断迁移到 `stdenv.hostPlatform.*`

- 影响范围：所有主机求值；无行为变化，只消除 nixpkgs 的弃用 warning。
- 配置入口：`home/` 下 9 个模块与 `templates/bevy/flake.nix`，`stdenv.isLinux/isDarwin/isx86_64`
  改为 `stdenv.hostPlatform.*`。
- 验证方式：`just test` 通过；apollo toplevel 求值后，本仓库不再产生该 warning。剩余 1 条
  `stdenv.isLinux` 来自 home-manager 上游 `modules/systemd.nix`，需等待上游修复后更新 input。
- 关联文档：[NixOS 内核策略](./nixos-kernel.md)（nixpkgs unstable 弃用项迁移记录）。

### apollo rEFInd 只保留最新 generation，显示文字标签并补齐图标

- 影响范围：apollo 启动菜单；下一次 `nixos-rebuild boot/switch` 后生效。
- 配置入口：`hosts/olympians-apollo/default.nix`（`boot.loader.refind.maxGenerations`、`extraConfig`、`additionalFiles`）。
- 变更内容：`maxGenerations` 3 → 1，主菜单只剩最新 NixOS 与 Windows；`theme.conf` 改为内联并从
  `hideui` 去掉 `label`，选中项下方显示文字；把 `pkgs.refind` 官方 `icons/`
  复制到 ESP，修复主题缺失图标显示异常。
- 验证方式：求值 `maxGenerations` 为 `1`，`extraConfig` 不再含 `include` 与
  `label`，`additionalFiles` 含 `icons/func_*.png`；未执行 rebuild。
- 关联文档：[rEFInd 引导方案](./refind-boot.md)、[NixOS 内核策略](./nixos-kernel.md)。

## 2026-10-19

### 更新 my-secrets 并导入 Apollo GPG key

- 影响范围：`apollo` 本机 GnuPG keyring 与 `mysecrets` flake input；不执行系统切换。
- 配置入口：`flake.lock`（`mysecrets` 锁定到
  `3c47898ec321b636611b08168f6407fb695d4988`）；本机密钥导入到 `~/.gnupg`，不写入仓库。
- 变更内容：从 `/home/vitus/my-secrets` 拉取最新提交，使用仓库 `master_key` 解密
  `gpg-secret-key.asc.age` 并导入当前用户 GnuPG；password-store 目录为空，因此没有旧 Ryan
  key 或密码条目需要重加密。
- 验证方式：新 key 指纹为 `28B6E6EE83AD27206FFD7B9B34722BF3D1BD2EDC`；GPG 加解密往返与 `apollo`
  配置求值通过。`nixos-rebuild build --flake .#apollo` 因 QQ 下载源返回 404 失败，未执行 `switch`。
- 关联文档：[Secrets 管理](../secrets/README.md)、[密码仓库说明](../home/base/tui/password-store/README.md)。

### 浏览器定为 Zen + Chrome；apollo 新增 Slack、Notion、Linear 并分配工作区

- 影响范围：所有 Linux 桌面新增 Google Chrome；apollo 新增 Slack 与 Notion / Linear 网页 App。
- 配置入口：`home/linux/gui/base/browsers.nix`（Chrome，forceX11Compat 时走 X11）；新增
  `home/linux/gui/base/work-apps.nix`（`modules.desktop.workApps`，apollo 的 `home.nix` 开启）；
  `home/linux/gui/niri/conf/windowrules.kdl`（Chrome → `2browser`，Notion / Linear → `3docs`，Slack
  → `6chat`）；
  `hosts/_shared/preservation.nix`（`.config/google-chrome`、`.local/share/webapps`、`.config/Slack`）。
- 变更内容：Notion、Linear 没有官方 Linux 客户端，用 Chrome `--app` + 独立 `--user-data-dir` +
  `--class` 打开官方网页，不使用第三方 Electron 包装。不安装 Chromium。
- 验证方式：apollo `home.packages` 含
  `slack-4.51.180`、`google-chrome-155.0.8059.79`，不含 Chromium；generic 只含 Chrome；`desktopEntries.{notion,linear}.exec`
  求值正确；GitHub Actions eval。窗口 app-id 需部署后用 `niri msg windows` 实测确认。
- 待办：Claude Desktop 官方 Linux Beta 仅提供 `.deb`，待自行打包。
- 关联文档：[浏览器与工作协作应用](./work-apps.md)、[Niri 工作区与窗口分配](./niri-workspaces.md)。

### 删除剩余的上游 ryan4yin 内容：图片、头像、外部链接

- 影响范围：noctalia 头像改为读取 `~/.face`（原指向上游作者的个人照片
  `_img/myself.jpg`）；其余为文档与注释。
- 配置入口：删除 `_img/`（5 张图均为上游作者提交，包括 README 中的桌面截图和个人照片）；
  `home/linux/gui/base/noctalia/config/settings.json`（`avatarImage`）；README 删除截图、上游的参考仓库列表和 fork 说明，“学习资料”改为 NixOS
  / Nix / Home Manager / nix-darwin 官方文档；`flake.nix`、`overlays/README.md`、
  `modules/darwin/README.md`、`home/base/tui/gpg/README.md`
  中指向上游作者书籍和博客的链接改为官方文档或删除；neovim `astrocore.lua`
  注释改为直接说明原因；`hosts/olympians-apollo/README.md` 删除上游 GPU 服务器的 DCGM 待办。
- 保留：`LICENSE` 中原作者的 MIT 版权声明（协议要求衍生作品保留）；`agenix`
  输入的作者 ryantm 是 agenix 官方维护者，不是上游作者。
- 后续：把自己的头像放到 `~/.face`，noctalia 即显示；文件不存在时显示默认头像。
- 验证方式：`flake.nix` 语法解析、`settings.json`
  JSON 校验通过；全仓库检索无剩余上游作者引用（LICENSE 与历史记录除外）。
- 关联文档：[文档索引](./README.md)。

### 清除上游 ryan4yin 遗留：根证书信任、GPG key、nixpkgs fork 与无主配置

- 影响范围：所有 NixOS / macOS 主机不再信任 `Ryan4Yin's Root CA 1`；noctalia-shell `4.4.3` →
  `4.7.7`；pass 不再固定 Ryan 的 GPG key；GPG 公钥环改为可写；`nix.distributedBuilds`
  关闭（构建机列表原本为空）。
- 安全：`modules/base/security.nix`
  曾把上游作者的私有根证书（私钥不在本仓库，有效期至 2034）加入系统信任库，持有该私钥者可签发本机信任的任意 TLS 证书，现已移除并删除
  `certs/`。
- 配置入口：
  - 删除
    `modules/base/security.nix`、`certs/`、`modules/nixos/base/remote-building.nix`、`infra/`（上游 homelab
    MinIO Terraform）、`nixos-installer/`（引用已不存在的
    `hosts/olympians-apollo/preservation.nix`，无法求值）。
  - `secrets/nixos.nix`：删除从未启用的 `modules.secrets.server.*` 六个选项及其引用的十余个不存在于
    `my-secrets` 的密钥；删除注释掉的上游 GPG / WireGuard / rclone /
    SMB 条目。桌面生效的 5 个 secret 不变。 `secrets/darwin.nix` 同样清理注释条目。`my-secrets`
    仓库未改动。
  - `home/base/tui/password-store/default.nix`：删除 `PASSWORD_STORE_KEY` /
    `PASSWORD_STORE_SIGNING_KEY` （上游作者的 key
    ID）；`home/base/tui/gpg/default.nix`：`mutableKeys` / `mutableTrust` 改为 `true`。
  - `flake.nix`：删除 `nixpkgs-patched`（ryan4yin/nixpkgs fork，停在 2026-02）；noctalia 改用
    `pkgs.noctalia-shell`。 `nu_scripts` 改指向上游 `nushell/nu_scripts`，锁定 rev `a571833`
    本身在上游历史中，内容不变。
  - `modules/nixos/base/monitoring.nix`：node exporter 排除规则里写死的 `home/ryan` 改为
    `myvars.username`。
  - `Justfile`：`up-nix` 去掉已删除的 `nixpkgs-patched`；删除触发上游仓库 workflow 的 `pkg-review`
    系列命令。
  - `LICENSE` 保留原作者 MIT 版权声明并追加本仓库作者；README 注明 fork 来源。
  - 旧安装器中的 LUKS + Btrfs 示例迁移为 [LUKS + Btrfs 分区示例](./luks-btrfs-layout.md)。
- 验证方式：apollo 求值 `home.packages` 含 `noctalia-shell-4.7.7`；`age.secrets` 为原 5 项；
  `security.pki.certificateFiles` 为空；所有改动的 `.nix` 语法解析通过；GitHub Actions eval。
- 后续：如需使用 pass，在本机 `gpg --full-generate-key` 生成自己的 key 后执行 `pass init <key ID>`。
- 关联文档：[文档索引](./README.md)、[应用版本审计](./application-version-audit.md)。

### apollo rEFInd 保留 generation 数 1 → 3

- 影响范围：apollo 启动菜单；下一次 `nixos-rebuild boot/switch` 后生效。
- 配置入口：`hosts/olympians-apollo/default.nix`（`boot.loader.refind.maxGenerations`）。
- 变更内容：为切换 6.18 LTS 内核保留回滚入口。NixOS
  rEFInd 模块按从新到旧排列 generation，最新项仍排第 2 位， `default_selection 2` 默认启动不变。
- 验证方式：`nixosConfigurations.apollo.config.boot.loader.refind.maxGenerations` 求值为
  `3`；核对 nixpkgs `refind-install.py` 的排序逻辑。
- 关联文档：[rEFInd 引导方案](./refind-boot.md)、[NixOS 内核策略](./nixos-kernel.md)。

### 内核从已删除的 7.0 切到 6.18 LTS，修复 CI 与 apollo rebuild

- 影响范围：`apollo`、`generic` 的内核（及随内核构建的 NVIDIA 模块）；下一次 rebuild + 重启生效。
- 根因：2026-10-17 主 nixpkgs 更新到 `55bfb4d` 后，`linuxPackages_7_0` 因上游 EOL 被删除（变为
  `throw`），所有 NixOS 主机求值失败。自那以后 GitHub Actions
  eval 持续失败，apollo 也无法 rebuild。报错由上一条新增的 CI annotation 暴露。
- 配置入口：`hosts/olympians-apollo/default.nix`、`hosts/olympians-generic/default.nix`：
  `pkgs.linuxPackages_7_0` → `pkgs.linuxPackages_6_18`。
- 验证方式：`nixosConfigurations.{apollo,generic}.config.boot.kernelPackages.kernel.version` 求值为
  `6.18.56`；apollo `hardware.nvidia.package` 求值为 `nvidia-x11-595.104.02`；GitHub Actions
  eval 复跑。
- 部署注意：apollo 的 rEFInd 只保留 1 个 generation，重启前先临时调高
  `boot.loader.refind.maxGenerations` 以保留旧内核回滚入口。
- 关联文档：[NixOS 内核策略](./nixos-kernel.md)。

### 删除 athena 主机；CI 暴露求值报错并检查测试结果

- 影响范围：移除 `nixosConfigurations.athena`；所有 NixOS 主机的 `authorized_keys` 不再包含
  `vitus@athena` 公钥；ssh 配置去掉 `athena` 别名。其余主机配置不变。
- 背景：athena 源自上游
  `idols-ai`，2026-03 换成一台 AMD 笔记本（提交中称 vitus8500）短暂使用，4 月后无维护；其网络仍是上游的 systemd-networkd 静态 IP（`eno1`
  占位地址），按现状部署会断网，README 也是上游 GPU 主机的磁盘布局。
- 配置入口：删除 `hosts/olympians-athena/`、`outputs/x86_64-linux/src/olympians-athena.nix`；
  `outputs/x86_64-linux/tests/{home-manager,hostname}`
  去掉 athena 断言；`vars/networking.nix`（`hostsAddr.athena`）、
  `vars/default.nix`（公钥）、`home/base/tui/ssh.nix`（别名）；相关专题文档同步去掉 athena。
  `my-secrets` 未把 athena 公钥作为 recipient，无需 rekey。
- CI：`.github/workflows/flake_evaltests.yml` 求值失败时把日志尾部写成 annotation；并检查
  `evalTests` 结果必须为 `true`（此前断言失败时 `nix eval` 仍以 0 退出，CI 不会变红）。
- 验证方式：所有 `.nix` 语法解析通过；CI 脚本用模拟 `nix` 验证报错 / false / true 三种分支。
- 关联文档：[主机配置](../hosts/README.md)。

### 仓库结构梳理：清理 fork 遗留物、去重配置、新增文档索引

- 影响范围：仓库结构与文档；唯一的配置行为变化是删除了重复的 zellij 模块（最终生效配置不变）。
- 配置入口：
  - `home/base/core/zellij/`：删除。它是 `home/base/tui/zellij/` 的子集（`core` 与 `tui`
    在所有平台都成对导入），别名 `zj` 与 `programs.zellij.enable` 仍由 `tui/zellij` 提供。
  - `outputs/x86_64-linux/src/olympians-{apollo,athena,generic}.nix`：删除签名里未使用的 `niri`
    参数（flake 没有 `niri` 输入；haumea 惰性传参所以过去不会报错，但会误导读者）。
  - `flake.nix`：description 改为本仓库；删除已失效的 asahi / nur 注释输入和旧版本 URL 注释。
  - `outputs/default.nix`：删除注释掉的 `pkgs-unstable` 代码块。
- 仓库清理：删除 14 张未被引用、继承自上游 ryan4yin 仓库的 `_img/` 图片；删除指向 ryan4yin 的
  `.github/FUNDING.yml` 和推送到上游 Gitee 的已禁用 `mirror_to_gitee.yml`；`docs/` 合并进
  `documents/`（`homebrew-tuna-troubleshooting.md` 移入，执行完的计划移到 `documents/plans/`）。
- 文档：新增 [文档索引](./README.md)；根 `README.md`
  补齐目录表（`lib/`、`certs/`、`scripts/`、`AGENTS.md`），新增“一台主机是怎么拼出来的”和“想改某样东西去哪里”速查；`hosts/README.md`
  的命名规则改为表格并说明 `hermes` 的特殊性，分布式构建一节改为如实描述（`buildMachines` 为空）；
  `outputs/README.md` 补上 `hestia`；`AGENTS.md` 要求新文档加入索引。
- 验证方式：所有 `.nix` 文件 `nix-instantiate --parse`
  通过；Markdown 相对链接检查无新增死链。沙箱无法拉取 private `mysecrets`，未运行完整
  `just test`，需要在本机补跑。
- 关联文档：[文档索引](./README.md)、[主机配置](../hosts/README.md)。

### omp 新增 DeepSeek 官方 provider，key 沿用现有 age 加密包

- 影响范围：OMP 新增 `deepseek/deepseek-flash`、`deepseek/deepseek-v4-pro` 两个模型；
  `my-secrets/omp-keys.age` 新增第 7 个 provider key，原有 6 个 key 与 8 个 recipients 保持不变。
- 配置入口：`home/base/core/omp-models.yml.in`（官方端点 `https://api.deepseek.com`，
  `api: openai-completions`）、`home/base/core/omp-sync.py`（增加 `@DEEPSEEK_KEY@` 缺失校验）、
  `secrets/darwin.nix`（同步密钥说明）、`my-secrets/omp-keys.age`（追加 `deepseek:` 后重新加密）。
- 密钥版本：`my-secrets` 已发布提交 `78defe1`，`flake.lock` 的 `mysecrets` input 同步锁定该提交。
- 变更内容：沿用模板占位符、agenix 解密与 `omp-sync-models` 生成链路，不改变默认模型或角色映射。新增
  `home/base/core/test_omp_sync.py`，防止缺少 DeepSeek key 时生成未替换的配置。
- 验证方式：age 加密回读一致且旧 key 保留；官方 `GET /models`
  返回 200 及上述两个名称；实际生成配置无残留占位符、权限 `0600`；`omp models find deepseek`
  能识别新增模型；隔离 agent 目录中的 OMP
  17.3.4 分别以 Flash 推理模式和 Pro 非推理模式发送短请求，均正常响应；
  `python3 home/base/core/test_omp_sync.py` 通过。
- 验证限制：完整 `nix eval .#evalTests` 在 Catppuccin `whiskers-2.9.0`
  依赖构建/测试阶段达到 240 秒超时，未得到完整求值结果；本次 Nix 文件仅更新注释，独立语法解析通过。
- 发布状态：密钥已提交推送，`mysecrets` 锁定已更新；未切换系统或覆盖本机
  `models.yml`。目标主机重建并重新解密后，仍需运行 `omp-sync-models` 同步模型配置。
- 关联文档：[omp 模型配置管理](./omp-models.md#deepseek-provider)、`my-secrets/README.md`。

## 2026-10-17

### omp models.yml 新增 glm provider（GLM Coding Plan key 入 my-secrets）

- 影响范围：omp 可选模型（新增 `glm/glm-5.3`、`glm/glm-5.3-flash`、`glm/glm-5.2`）；my-secrets
  `omp-keys.age`（第 6 个 key）。
- 配置入口：`my-secrets/omp-keys.age`（追加 `glm:` 行，`30d3295`）、
  `home/base/core/omp-models.yml.in`（glm provider 块，baseUrl
  `https://open.bigmodel.cn/api/coding/paas/v4`，`api: openai-completions`）、
  `home/base/core/omp-sync.py`（占位符校验加 `@GLM_KEY@`）、`flake.lock`（mysecrets 锁定）。
- 变更内容：GLM Coding
  Plan 的 key 由用户直接提供并入密钥库；模板/同步脚本/文档同步。此后新增模型统一走
  [omp 模型配置管理](./omp-models.md) 的标准流程。
- 验证方式：`omp models find glm` 列出 3 个模型；curl 实测 bigmodel 端点 `glm-5.3` 返回正常；生成的
  `.models.generated.yml` glm 块 key 注入完整、零残留占位符。
- 注意：`agenix -e`
  在非交互 stdin 下会把明文写空（本次踩坑，已从 git 恢复），必须在真实 TTY/PTY 中执行；已写入 omp-models.md 标准流程。
- 关联文档：[omp 模型配置管理](./omp-models.md)。

### 网络切换软路由透明代理，清理本地 7890 残留并恢复 hindsight 记忆后端

- 影响范围：全机出网路径（不再依赖本地代理进程）；brew 激活环境；docker 容器环境注入；omp 记忆后端（hindsight）可用性；proxychains 使用者。
- 配置入口：`modules/darwin/apps.nix`（移除注入 brew 环境的
  `local_proxy_env`，只保留 nju 镜像）、`modules/darwin/hindsight-compose.yml`（LLM 由失效 DashScope
  `qwen3.8-flash` 切至relay `gemini-3.1-flash-lite`，删除 qwen 专属
  `HINDSIGHT_API_LLM_EXTRA_BODY`）、删除 `home/darwin/proxy/` 与
  `scripts/darwin_set_proxy.py`（指向已下线的 `192.168.5.101`）；仓库外：`~/.docker/config.json`
  移除 `proxies` 段、`~/.config/hindsight/hindsight.env` 换存relay
  key、`~/work/shopping-console/.env.local` 删 `HTTP(S)_PROXY`；`Justfile` 删除引用已删脚本的
  `darwin-set-proxy` 目标。
- 变更内容：FlClash 停用后四处配置仍指向 `127.0.0.1:7890`，其中 `~/.docker/config.json` 的
  `proxies.default` 给 hindsight 容器注入死代理（`host.docker.internal:7890`）导致 crash
  loop、omp 报 "Unable to connect"；重建容器后恢复，其 DashScope
  key 已被吊销（401），随 bailian 全线退役切至 relay（当日 relay
  gpt 系 502/503，gemini 实测 200）。出网由软路由透明代理承担（IPv6 软路由侧已关闭），此后网络设置变更必须先与用户同步。
- 验证方式：hindsight `/health` 200、日志
  `Connection verified: openai/gemini-3.1-flash-lite`、omp 会话内 recall 实测返回记忆；`nix eval .#debugAttrs.allSystems.aarch64-darwin.evalTests`
  = `{ }`（`just test` 全系统通道在 HEAD 干净副本同样失败于 hermes
  x86_64-linux 存量问题，与本次改动无关）。
- 后续清理（同日）：`/Applications/FlClash.app` 与 `~/Library/Application Support/com.follow.clash`
  （37M，含订阅）移入 `~/.Trash/flclash-cleanup-20261017/`（可恢复）；`aerospace.toml` 删除
  `com.follow.clash` 窗口规则并同步
  `aerospace-usage.md`；`nix-collect-garbage --delete-older-than 7d`
  清理 16920 个旧 store 路径（复检 0 残留）；`brew cleanup` 清空 44M 缓存；docker 无悬空镜像。
- 部署状态：`darwin-rebuild switch` 已执行（generation
  `26.11.4cff07d`），brew 激活环境确认无 proxy 导出，`~/.proxychains`
  已被 home-manager 清理；`~/.aerospace.toml` 为符号链接，AeroSpace 自动重载新规则。
- 关联文档：[网络与代理策略](./network-proxy.md)、[Hindsight 记忆后端](./hindsight.md)。

### 移除已吊销的 bailian provider，Codex 切回 scitrace relay

- 影响范围：omp 可用 provider 列表（少 bailian）；Codex CLI 后端与鉴权。
- 配置入口：`home/base/core/omp-models.yml.in`（删 bailian 段）、
  `home/base/core/omp-sync.py`（占位符校验列表去掉 `@BAILIAN_KEY@`）、
  `secrets/darwin.nix`（注释）；本机 `~/.omp/agent/.models.generated.yml` 已重新生成、
  `~/.codex/config.toml`（custom provider → `https://sub.scitrace.cc/v1`，模型
  `gpt-5.5`）、`~/.codex/auth.json`（relay key，旧 key 备份为 `auth.json.bak-bailian-20261017`）。
- 变更内容：bailian（DashScope 直连）key 被吊销，旧新两把 key 在百炼均报
  `InvalidApiKey`/`invalid_api_key`；Codex 原配置把 relay 的 sk-ws key 发给百炼导致 401"API-key is
  blocked"（TUI 显示 Unable to connect）。已将 Codex 后端切回 scitrace relay（openai
  key 鉴权验证通过）。
- 验证方式：`codex exec` 实测请求已打到 `sub.scitrace.cc/v1/responses`
  且鉴权通过，当前仅剩 relay 上游 503（scitrace 服务端临时故障，恢复后即通）；重新生成的 models.yml 含 5 个 provider、key 完整；`nix eval .#debugAttrs.allSystems.aarch64-darwin.evalTests`
  = `{ }`。
- 后续处置（同日完成）：my-secrets 仓库已删除 bailian 行并重新加密推送（omp-keys.age 75fc467 →
  37ad990，nix-config 同步
  `nix flake update mysecrets`）；sudoers 免密规则已安装，`darwin-rebuild switch` 已执行并激活。
- 关联文档：[omp 模型配置管理](./omp-models.md)。

### 更新 nu_scripts 输入修复 Nushell str downcase 弃用警告

- 影响范围：所有主机 Nushell 启动时加载的 `nu_scripts`
  模块（git 补全/别名、eza/bat 别名、argx、lg、kubernetes）；artemis 上每次开 shell 报
  `nu::parser::deprecated: str downcase was deprecated in 0.114.0`。
- 配置入口：`flake.lock`（单输入 `nix flake update nu_scripts`：ryan4yin fork ff80927 2025-11-11 →
  a571833 2026-09-20）。
- 变更内容：锁定 rev 的 `modules/kubernetes/env.nu` 仍用 `str downcase`（Nushell
  ≥0.114 弃用，未来版本移除）；新版 fork 已同步上游改为
  `str lowercase`，同时带来 git 补全等例行更新。本仓库 `use` 的 7 个模块路径在新 rev 均存在。
- 验证方式：本地 Nushell 0.115.1 `nu -n -c 'use ...'` 加载全部 7 个模块无任何弃用警告；
  `nix eval .#debugAttrs.allSystems.aarch64-darwin.evalTests` = `{ }`；同日已
  `darwin-rebuild switch` 激活，`nu --config ~/.config/nushell/config.nu` 完整加载零弃用警告。
- 关联文档：[Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)。

### 修复 herdr Pane 启动 Nushell 报 str lowercase 解析错误（default_shell 改稳定路径）

- 影响范围：所有主机（artemis / apollo）Herdr 交互式 Pane 的 shell 来源；artemis 上已触发的
  `nu::parser::extra_positional` 启动报错。
- 配置入口：`home/base/tui/dev-tools.nix`（herdr `terminal.default_shell`）。
- 变更内容：HM（master）生成的 fzf 集成脚本使用 Nushell `0.114.0` 才引入的 `str lowercase`
  语法；10-06 启动的 herdr server 内存中仍持有旧配置的 nushell-0.113.1
  store 绝对路径，新 Pane 用旧二进制解析 10-07 switch 后的新 `config.nu` 而报错。已对本机执行
  `herdr server reload-config`（返回 applied，立即修复新 Pane）； `default_shell` 由
  `${config.programs.nushell.package}/bin/nu` 改为
  `${config.home.profileDirectory}/bin/nu`（两台主机均求值为
  `/etc/profiles/per-user/vitus/bin/nu`），跨 rebuild 始终指向当前 generation 的 nu。另查明：apollo（主
  `nixpkgs`，nushell
  0.113.1）在升级该输入前执行 rebuild 会让全部新 shell 复现同样报错，最新 nixos-unstable 的 nushell 已为 0.116.1，需先
  `nix flake update nixpkgs` 再 rebuild。
- 验证方式：0.115.1 的 `nu --config ~/.config/nushell/config.nu -c 'print ok'`
  解析通过；用 0.113.1 二进制加载同一配置复现原报错；两主机
  `xdg.configFile."herdr/config.toml".text` 求值均为稳定 profile 路径；`nixfmt` 通过；
  `nix eval .#debugAttrs.allSystems.aarch64-darwin.evalTests` = `{ }`（顶层 `.#evalTests`
  撞 x86_64-linux catppuccin-starship 预存问题，与本次无关）。仓库改动生效需
  `darwin-rebuild switch`，未自动执行。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)、
  [Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)。

### 主 nixpkgs 输入更新至 2026-10-14（apollo nushell 0.116.1，解除 rebuild 限制）

- 影响范围：走主 `nixpkgs` 的全部 NixOS 主机（apollo / hestia 等）包集；artemis 走 `nixpkgs-darwin`
  输入，不受影响。
- 配置入口：`flake.lock`（单输入 `nix flake update nixpkgs`：6517942 2026-07-02 → 55bfb4d
  2026-10-14）。
- 变更内容：HM（master）的 fzf 集成脚本要求 Nushell ≥0.114（`str lowercase`），apollo 原 nushell
  0.113.1 直接 rebuild 会让全部新 shell 报
  `extra positional argument`（见上一条记录）。更新后 apollo 求值：Nushell `0.116.1`、Zellij
  `0.45.1`、fzf `0.74.5`、Atuin `18.23.0`，rebuild 限制解除；herdr `default_shell`
  仍为稳定 profile 路径。
- 验证方式：`flake.lock` diff 仅 nixpkgs 一个节点（±1 行 rev），无其他输入漂移；
  `nix eval .#debugAttrs.allSystems.aarch64-darwin.evalTests` =
  `{ }`（x86_64-linux 域在本机被 catppuccin-install-hook 交叉构建预存问题挡住，与 2026-09-30 记录同类，非本次回归）；同源 fzf 集成脚本已在 artemis
  Nushell 0.115.1 上实测解析通过。未在 apollo 上执行 rebuild（需到主机操作或远程部署）。
- 关联文档：[Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)、
  [Herdr Agent 终端运行时](./herdr.md)。

## 2026-10-07

### darwin-rebuild 裸 switch 可用（/etc/nix-darwin 指向仓库 flake）

- 影响范围：artemis 本机部署工作流（`/etc/nix-darwin/flake.nix`）。
- 变更内容：`/etc/nix-darwin/flake.nix` 是 2025-11 的 nix-darwin 示例 flake 残留，裸
  `darwin-rebuild switch`（NOPASSWD 白名单只放行无参数形式）会构建它并报
  `undefined variable 'system'`。已将原文件改名为 `flake.nix.orig-2025-11`，新建符号链接指向
  `/Users/vitus/nix-config/flake.nix`；darwin-rebuild 通过 `readlink -f`
  解析到真实 flake，`scutil LocalHostName=artemis` 匹配 `darwinConfigurations.artemis`。此后无参数
  `darwin-rebuild switch` 即可构建当前仓库配置，无需手动输密码，也无需 `--flake .#artemis`。
- 验证方式：`sudo darwin-rebuild switch` 成功构建并切换 artemis（222s）；新终端
  `env -i nu -c "source /run/agenix/alias-for-work.nushell"`
  验证 openai 指向 scitrace、kimi 变量零注入。
- 关联文档：[omp 模型配置（models.yml）管理](./omp-models.md)。

### 移除 kimi 固定 API，openai/anthropic 统一走 scitrace（models.yml 同源）

- 影响范围：`my-secrets/alias-for-work.nushell.age`（nushell 启动注入的环境变量）、
  `home/base/tui/shell/default.nix`（移除 kimi 注释示例）、本机 `~/.claude/settings.json`。
- 变更内容：
  - `alias-for-work.nushell` 删除全部 kimi 环境变量（`KIMI_API_KEY` / `KIMI_BASE_URL` /
    `KIMI_ANTHROPIC_*`）与 `use-kimi` 切换函数；`OPENAI_API_KEY` / `ANTHROPIC_AUTH_TOKEN` /
    `ANTHROPIC_BASE_URL` 默认固定为 scitrace 中转（`https://sub.scitrace.cc`），key 与
    `~/.omp/agent/models.yml` 中 openai / anthropic provider 完全一致；
  - `~/.claude/settings.json` 的 `ANTHROPIC_AUTH_TOKEN` / `ANTHROPIC_BASE_URL` 从 `timicc.com`
    改为 scitrace（key 同 models.yml anthropic）。
- 密文已用 `my-secrets/secrets.nix` 的 8 个 recipients 重新加密，`master_key` 解密往返验证一致。
- 验证方式：`nu -c "source /tmp/alias-for-work.new.nu"` 语法通过且无 kimi 残留；旧
  `alias-for-work.nushell.age` 备份于 `/tmp/alias-for-work.nushell.age.bak`；
  `~/.claude/settings.json` JSON 校验通过。生效需 `darwin-rebuild switch`（重新解密
  `/run/agenix/alias-for-work.nushell`）后新开终端。
- 关联文档：[nushell AI agent 快捷命令](./nushell-ai-agent-aliases.md)、
  [omp 模型配置管理](./omp-models.md)。

## 2026-10-01

### darwin 开启 nix 自动 gc

- 影响范围：artemis（aarch64-darwin）nix 存储； `modules/darwin/nix-core.nix`。
- 变更内容：新增 `launchd.user.agents."nix-gc"` 定时任务（每周日 03:00 执行
  `nix-collect-garbage --delete-older-than 7d`），策略与 NixOS 侧（`modules/nixos/base/nix.nix`）对齐。不用 nix-darwin 的
  `nix.gc` 模块：artemis 由 Determinate Nix 接管 daemon（`nix.enable = false`）， `nix.gc.automatic`
  断言要求 `nix.enable` 且 `nix.gc.dates` 已废弃； `auto-optimise-store`
  保持关闭（NixOS/nix#7273）。
- 验证方式：`darwin-rebuild build --flake .#artemis` 通过；手动执行
  `nix-collect-garbage --delete-older-than 7d` 删除 4579 个死路径，释放 14.5 GB（`/nix/store` 49G →
  34G）。
- 关联文档：[nix 自动垃圾回收（gc）策略](./nix-gc.md)。

### sci-plus 移除无效模型条目（gpt-5.3-codex-spark / gpt-5.4）

- 影响范围：`~/.omp/agent/models.yml`（runtime）与
  `home/base/core/omp-models.yml.in`（nix-config 模板）；sci-plus 池模型 12 → 10 个。
- 变更内容：实测发现这两个模型 ID 不在 scitrace 网关 `/v1/models`
  列表中，调用必然模型不存在；从 sci-plus 移除（sci-pro-special 池中同名的两个模型在网关列表中有效，保留）。
- 验证方式：runtime 与模板的 sci-plus 区块逐行 diff 一致（仅 key 处为占位符/明文之分）；`omp models`
  正常列出 10 个模型。
- 关联文档：[omp 模型配置（models.yml）管理](./omp-models.md)。

### omp /model 选择器隐藏未配置 provider

- 影响范围：artemis 用户级 omp 配置 `~/.omp/agent/config.yml`（未入库）。
- 变更内容：新增 `disabledProviders`
  黑名单（35 个 omp 内置目录 provider，含 apple/azure/cerebras/groq/xai 等），模型选择器与
  `omp models` 列表仅显示实际配置的 6 个 provider（openai/anthropic/sci-plus/sci-pro-special/
  bailian/gemini）。`enabledProviders` 白名单实测不生效，故采用黑名单方案。
- 验证方式：`omp models --json`
  由 8 个 provider（含未配置的 moonshot、zhipu-coding-plan）降为 6 个配置 provider。
- 关联文档：[omp 模型配置（models.yml）管理](./omp-models.md)。

### slow/smol 模型角色切换为 qwen3.8-flash

- 影响范围：artemis 用户级 omp 配置（`~/.omp/agent/config.yml`，未入库）。
- 变更内容：`modelRoles.slow/smol` 由 `openai/gpt-5.5` 改为 `bailian/qwen3.8-flash`
  （原指向的 openai 池处于 503 故障）；`default` 保持 `bailian/glm-5.2-fast-preview`。
- 验证方式：角色引用一致性校验通过。

### scitrace 账户通道上下文窗口实测（重点 gpt-6-astra）

- 影响范围：`sci-pro-special` provider 4 个模型的 `contextWindow` 按实测更新。
- 变更内容：实测确认账户通道上限 = 官方 `max input tokens`（非总窗口）：gpt-6-astra / gpt-5.6-sol /
  gpt-5.6-terra ≈ **920K**（920008 OK / 922K OOW，多次复现，与官方 922,000 max
  input 精确吻合）；gpt-5.5 仅 ≈ **268K**。超限以 SSE `response.failed` + `context_length_exceeded`
  拒绝，无静默截断。对应模型 `contextWindow` 已写入 920000 / 260000；其余模型因池 503 未测得。
- 关联文档：[omp 模型配置（models.yml）管理](./omp-models.md)。

### omp 新增 scitrace 中转 provider（openai/anthropic/sci-plus/sci-pro-special）

- 影响范围：`~/.omp/agent/models.yml`（后随本次迁移并入 nix-config 模板）的 provider 目录；API
  key 已迁入 my-secrets 加密管理。
- 变更内容：新增 4 个 provider，统一 `baseUrl = https://sub.scitrace.cc`：
  `openai`（8 个 GPT，sk-c515…）、`anthropic`（15 个 claude，`api: anthropic-messages`
  原生协议，sk-1c07…）、`sci-plus`（12 个 GPT，sk-1d20…）、`sci-pro-special`
  （11 个 GPT，sk-b659…）。健康状态：anthropic / sci-pro-special 可用，openai /
  sci-plus 上游账户池 503（间歇性恢复）。
- 验证方式：`/v1/models` 200；各池最小推理请求 OK；omp 端到端 `--model` 实测（claude-opus-5 /
  gpt-5.5 / gemini-3.1-pro-high 均通过）。

### omp models.yml 迁入 nix-config（软链接）+ API key 加密至 my-secrets

- 影响范围：artemis（aarch64-darwin）用户级 omp 模型 catalog；`~/.omp/agent/models.yml`
  由用户直写文件改为 nix-config 管理的软链接；6 个 provider（openai/anthropic/sci-plus/
  sci-pro-special/bailian/gemini）的 API key 不再明文落盘于仓库之外的点，改由 age 加密。
- 配置入口：`home/base/core/omp.nix`（`home.activation.ompModels` 生成逻辑 + `omp-sync-models`
  命令）、`home/base/core/omp-models.yml.in`（模型模板，key 为 `@XXX_KEY@`
  占位符）、`secrets/darwin.nix`（`age.secrets."omp-keys"`，解密至
  `/run/agenix/omp-keys`）、my-secrets 仓库的 `omp-keys.age` 与 `secrets.nix`。
- 变更内容：模板（无 key）进 Nix store；key 由 agenix 运行时注入，生成
  `~/.omp/agent/.models.generated.yml`，`models.yml`
  为指向它的软链接。B 模式：仅当目标缺失或非软链时生成，重建不覆盖用户手改；手动 `omp-sync-models`
  可从模板重置。
- 验证方式：`ls -l ~/.omp/agent/models.yml` 为软链接；生成文件无 `@…@` 残留；
  `omp --model anthropic/claude-opus-5 -p` 真实推理通过；`omp --version` 无 Permission denied；Nix
  store 无 key 明文。
- 关联文档：[omp 模型配置（models.yml）管理](./omp-models.md)。

### omp 部署 sudo 自动化（sudoers 白名单）

- 影响范围：artemis（aarch64-darwin）；无 tty 场景（omp agent / 脚本）下
  `darwin-rebuild switch`（`just local`）免人工输密码。
- 配置入口：`/etc/sudoers.d/nix-darwin`（一条 NOPASSWD 规则，仅放行
  `darwin-rebuild switch`，通配 store 哈希）。
- 变更内容：sudoers 白名单只对 `darwin-rebuild switch`
  开放免密，其余 sudo 照旧要求密码（最小权限，区别于全量 NOPASSWD/Keychain askpass 方案）。
- 验证方式：`just local`（darwin-rebuild switch）无 tty 下全程无需输密码；其他 sudo 命令仍提示密码。
- 关联文档：[omp 模型配置（models.yml）管理](./omp-models.md#一键部署的-sudo-自动化sudoers-白名单)。

### omp 新增 gemini provider（scitrace 中转 Gemini 系列）

- 影响范围：artemis（aarch64-darwin）用户级 omp 模型 catalog，不涉及 `modelRoles`。
- 配置入口：`~/.omp/agent/models.yml`（新增 `gemini` provider，备份
  `~/.omp/agent/models.yml.bak-20261001-gemini`）。
- 变更内容：新增 `gemini` provider，`baseUrl = https://sub.scitrace.cc`（无 `/v1`、无尾斜杠）、
  `api = openai-responses`、独立 API key。中转 `/v1/models` 列出 18 个 gemini
  id，逐个实测后只写入 10 个可用模型（`gemini-3.1-pro-high/-low`、`gemini-3.7-flash-high/-medium/-low`、
  `gemini-3.6-flash-high/-medium/-low/-tiered`、`gemini-3.1-flash-lite`），统一按 1M 输入 /
  64K 输出、text+image 配置；其余 8 个（3.8-flash 全系、`gemini-3-flash`、`gemini-3.5-flash-lite`、2.5 系列）返回 503
  `No available accounts ... (channel pricing restriction)`，不入库。
- 验证方式：`GET /v1/models` = 200；`gemini-3.1-pro-high` 在 `/v1/responses` 与
  `/v1/chat/completions` 均 200，流式 SSE 到 `response.completed`，工具调用分别返回 `function_call`
  / `tool_calls`，图片输入正确识别颜色；`omp models gemini` 列出 10 个模型；
  `omp --model gemini/gemini-3.1-pro-high --no-tools -p "只输出 OK"` 输出 `OK`；带工具会话跑
  `echo gemini-tool-ok` 返回
  `gemini-tool-ok`。窗口实测（10 个模型全测）：约 1.05M 输入对每个模型都返回 400 并点名
  `1048576`，`pro-high` 另测 100K/300K/600K/900K 唯一输入均 200；输出上限约 `65532`，由
  `pro-high`（407s）与
  `3.6-flash-high`（776s）撞到且数值一致，其余 8 个模型提示词逼不到上限（自行收尾于几百~2 万 tokens），但
  `max_output_tokens: 65536` 对 10/10 返回 200。 `max_output_tokens`
  网关完全不校验（填 1M 回 200，填 200 时 10/10 实际输出 2285~15630 超限），且截断仍报
  `status: completed`、`incomplete_details: null`。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

## 2026-09-30

### omp 解绑 nix-config：改用户级 bun 全局安装

- 影响范围：artemis（aarch64-darwin）用户级 omp 安装/配置/PATH。
- 配置入口：删除 `home/base/core/omp.nix` 与 `flake.nix`/`flake.lock` 的 `omp` input；
  `home/base/core/shells/default.nix`、`home/base/core/shells/config.nu`（PATH 加
  `~/.cache/.bun/bin`）；`~/.omp/agent/config.yml`（由 home-manager store
  symlink 转回用户级可写普通文件，内容保留 memory/hindsight 与 modelRoles）。
- 变更内容：`programs.omp` 声明式管理生成的 config.yml 位于 nix store 只读路径，omp 启动写
  `config.yml.lock` 报 Permission denied（os error 13）；且 omp 更新绑定 `nix flake update omp` +
  `just local`，构建慢。现改为官方推荐的 bun 全局安装
  `@oh-my-pi/pi-coding-agent`（当前 18.4.4），更新走 `bun update -g`，与 nix-config 解耦。
- 验证方式：`omp --smoke-test` = ok；config.yml 为普通文件且 .lock 可写；
  `nix eval .#debugAttrs.allSystems.aarch64-darwin.evalTests` = `{ }`（注：顶层
  `nix eval .#evalTests` 在 darwin 上因 x86_64-linux 主机 catppuccin-starship
  install-hook 构建失败，为预存问题，与本次改动无关）。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)、
  [应用版本审计](./application-version-audit.md)、[Hindsight 记忆后端](./hindsight.md)。

## 2026-09-28

### AeroSpace：Chrome 窗口自动归入 2Browser 工作区

- 影响范围：artemis（aarch64-darwin）AeroSpace 窗口规则与使用文档。
- 配置入口：`home/darwin/aerospace/aerospace.toml`（`on-window-detected`）、
  `documents/aerospace-usage.md`（2Browser 应用表）。
- 变更内容：新增 `com.google.Chrome` → `2Browser` 的 `on-window-detected`
  规则，与 Zen 同区；文档同步标注。
- 验证方式：规则语法静态检查；未重建系统，未对 AeroSpace 实例热重载验证。
- 关联文档：[AeroSpace 使用指南](./aerospace-usage.md)。

### 修复 herdr 0.7.1 macOS 构建：补齐 cctools/xcbuild/apple-sdk_15

- 影响范围：artemis（aarch64-darwin）nix-darwin overlay。
- 配置入口：`lib/macosSystem.nix`（overlay `herdr.overrideAttrs`）。
- 变更内容：herdr 0.7.1 的 zig 构建经 `xcode-select --print-path` +
  `xcrun --sdk macosx --show-sdk-path` 探测 macOS
  SDK，但包定义未引入 cctools/xcbuild，构建环境缺这两个命令。补齐
  `nativeBuildInputs`（cctools、xcbuild、apple-sdk_15）并在 `preConfigure` 显式导出
  `DEVELOPER_DIR`/`SDKROOT` 兜底（\_\_structuredAttrs 环境下 setup
  hook 不生效）。必须用 apple-sdk_15：zig 0.15.2 链接 build_runner 时与 SDK
  26 的 libSystem.tbd 不兼容（undefined symbol），SDK 15 实测正常。nixpkgs 升级到含 herdr
  0.8.2+（已补齐依赖）后可移除。
- 验证方式：herdr 0.7.1 在 darwin 构建通过（build_runner 链接成功）；完整系统未重建。
- 关联文档：无专题文档，约束记录在 `lib/macosSystem.nix` 注释内。

### 修复 home.activation 片段 exit 中断 Home Manager 激活（atuin/Nushell 报错）

- 影响范围：artemis（aarch64-darwin）Home Manager 激活流程。
- 配置入口：`home/base/core/git.nix`（`home.activation.backupExistingGithubToken`）。
- 变更内容：当 `github_token` 已链接到 agenix 路径时，激活片段由 `exit 0`
  改为空命令跳过——片段被内联进激活脚本顶层，`exit`
  会终止整个激活，文件链接等后续步骤从未部署（Nushell 仍读旧 generation 的
  `config.nu`，其 atuin 集成为旧版生成的 `job spawn -t atuin`，触发 Nushell
  0.113.1 的 unknown_flag 报错）。排查细节见 `documents/nushell-zellij-startup.md`。
- 验证方式：激活不再被提前终止；`~/.config/nushell/config.nu`
  随下次 switch 部署为当前 generation 内容（静态核对激活脚本逻辑，未重建系统）。
- 关联文档：[Nushell + Zellij 启动链路](./nushell-zellij-startup.md)。

## 2026-09-15

### darwin（artemis）代理客户端由 Clash Verge 替换为 FlClash

- 影响范围：artemis（aarch64-darwin）代理 GUI 与命令行代理依赖。
- 配置入口：`modules/darwin/apps.nix`（FlClash 安装说明注释）、
  `home/darwin/proxy/default.nix`（移除 `clash-meta` 包）、
  `home/darwin/proxy/proxychains.conf`（注释更新，端口不变）。
- 变更内容：卸载 Homebrew cask `clash-verge-rev`（Clash Verge 2.5.2，备份于
  `/opt/homebrew/Caskroom/clash-verge-rev`），改用手动安装官方FlClash 0.8.98（macOS arm64 dmg，
  `https://github.com/chen08209/FlClash/releases`，sha256
  `daaa8449f6b0e67ced7aa0472df2f15befbd5ed5944f36da4f90b0051a38ddb1`）。FlClash 无 Homebrew
  cask、nixpkgs 无包，与 Linux 侧同源。 `home/darwin/proxy/default.nix` 中移除无实际用途的
  `clash-meta` （mihomo 内核 CLI：无进程、无配置目录；FlClash 内置内核）。订阅沿用
  `~/Library/Application Support/com.follow.clash`
  既有 3 条（Selom/赔钱机场/一元机场），无需重配；将偏好 `flutter.config` 中
  `appSettingProps.autoRun` 置 `true`，使内核服务随 FlClash 启动运行。mixed-port `7890`
  与 proxychains `socks5 127.0.0.1 7890` 一致，AeroSpace 窗口规则（`com.follow.clash` →
  `0Other`）沿用无需改动。
- 验证方式：`brew uninstall --cask clash-verge-rev` 后 `/Applications/Clash Verge.app`
  与进程均移除；FlClashCore 监听 `127.0.0.1:7890`；经 HTTP 与 SOCKS5 代理访问
  `https://www.gstatic.com/generate_204` 实测均 204。
- 关联文档：[应用版本审计](./application-version-audit.md)、
  [AeroSpace 使用指南](./aerospace-usage.md)。

## 2026-09-13

### 新增 hestia（NixOS-WSL 终端主机）并完成首次部署

- 影响范围：新增 WSL 终端主机 `hestia`；`flake.nix` 新增 `nixos-wsl` input； `my-secrets` 新增
  `hestia-wsl` recipient 并 rekey 全部 secrets。
- 配置入口：`flake.nix`、`flake.lock`、`outputs/x86_64-linux/src/hestia.nix`、
  `hosts/hestia/default.nix`、`hosts/hestia/home.nix`、
  `hosts/README.md`、`documents/hestia-wsl.md`。
- 变更内容：新增 WSL 专用终端主机
  `hestia`：仅 WSL 模块 + 终端链（`home/linux/tui.nix`），不导入桌面 / secrets / preservation /
  hardening； `wsl.defaultUser = "vitus"`，主机名 `hestia`；保留 `bb` 服务并改为以 `vitus`
  运行（目录迁至 `/home/vitus/bb-app`）；`dconf` 关闭、HM 激活不启动用户单元； `nix.extraOptions`
  引用手工放置的 `/etc/agenix/nix-access-tokens`（不进仓库）； `my-secrets` 增加 `hestia-wsl`
  公钥（`~/.ssh/id_ed25519`）并用 `master_key` rekey。
- 验证方式：`nixos-rebuild switch --flake .#hestia` 成功（Generation 7，当前生效）；
  `bb`、`home-manager-vitus` 均为 active；`my-secrets` 全部 5 个 `.age` 文件可用
  `/home/vitus/.ssh/id_ed25519` 解密。 `lockscreen-pam`
  回归测试收窄到桌面主机（终端主机无 noctalia 锁屏）。
- 关联文档：[hestia WSL 主机](./hestia-wsl.md)、[主机配置](../hosts/README.md)。

### ssh config 新增 13t 主机别名

- 影响范围：所有接入 `home/base/tui/ssh.nix` 的主机（桌面与 WSL 终端主机）。
- 配置入口：`home/base/tui/ssh.nix`。
- 变更内容：新增 `13t` SSH 主机别名，指向 Tailscale 网段（`100.64/10`）的 `100.64.0.107`，SSH 端口
  `8022`，用户 `vitus`。
- 验证方式：`nix eval .#nixosConfigurations.hestia.config.home-manager.users.vitus.programs.ssh.settings --json`
  输出包含 `13t` 条目且 HostName / Port 正确（本机实测通过）。
- 关联文档：无（别名清单与说明见 `home/base/tui/ssh.nix`）。

## 2026-09-08

### 新增 Hindsight 本地记忆后端（docker 容器），接入 omp memory.backend

- 影响范围：artemis（aarch64-darwin）系统包、docker 运行时（colima）、hindsight 容器服务、omp memory
  backend（`~/.omp/agent/config.yml` 改为声明式）。
- 配置入口：`modules/darwin/apps.nix`（`environment.systemPackages` 用 nix 安装
  `docker`/`colima`/`docker-compose`，不经过 brew）、 `modules/darwin/hindsight.nix`（launchd
  agents： `hindsight-colima` 登录自启 colima、`hindsight-compose` RunAtLoad + 300s 兜底
  `docker-compose up -d`）、`modules/darwin/hindsight/docker-compose.yml` （容器编排，nix 模块经
  `builtins.readFile` 引用）、 `home/base/core/omp.nix`（`programs.omp.settings` 声明
  `memory.backend = hindsight` 与 `hindsight.scoping = per-project-tagged`，迁移原手工 `config.yml`
  的 `modelRoles`/`setupVersion`/`hideThinkingBlock`；旧文件备份为
  `~/.omp/agent/config.yml.home-manager.backup`）、
  `~/.config/hindsight/hindsight.env`（0600，dashscope API key，手工维护不入库）。
- 变更内容：hindsight 服务端以 `ghcr.io/vectorize-io/hindsight:latest`
  容器跑在 colima 本地 docker（REST API 8888 / Web UI 9999，嵌入式 pg0，数据卷
  `hindsight-data`）。LLM 走 omp 的 bailian provider（DashScope OpenAI 兼容端点）
  `qwen3.8-flash`（`HINDSIGHT_API_LLM_PROVIDER=openai` + `BASE_URL` +
  `MODEL`），embeddings/reranker 用镜像内建本地模型，无外部 embedding API。
  `HINDSIGHT_API_LLM_EXTRA_BODY={"chat_template_kwargs":{"enable_thinking":false}}`
  关闭模型思考模式（qwen3.8-flash 思考模式禁止强制 `tool_choice`，hindsight
  reflect/retain 会 400 并重试 4 次）。omp 每会话按 `per-project-tagged`
  scoping 写共享 bank + 项目 tag（仓库主根 basename 小写，如
  `project:nix-config`），recall 覆盖项目 tag 与未标记全局记忆。选型：全部 nix 声明式（工具链、服务生命周期、omp 配置），不依赖 brew
  services 与手动命令；API key 不入库。实施阻点与解法：GitHub TLS 干扰/断流 → 镜像经
  `ghcr.nju.edu.cn` 拉取后 tag 回官方名；colima VM 镜像经 ghfast.top 加速站下载（GitHub
  release-assets 的 HEAD 解析被拒）；nix docker 客户端不注册 `docker compose`
  插件，手动命令用独立二进制 `docker-compose`。
- 验证方式：`nix eval` 确认 systemPackages 含 docker-29.6.0/colima-0.10.1/ docker-compose-5.2.0 与
  `programs.omp.settings` 求值正确；`just local` 构建切换成功（含
  `omp-config.yml.drv`）；hindsight 容器日志 `Connection verified: openai/qwen3.8-flash`；API
  retain/recall/reflect 端到端 200（Rust 记忆可检索、reflect 综合回答正确、`thoughts_tokens=0`）；omp 会话自动创建
  `omp` bank，`[REFLECT omp-<pid>]` 无 tool_choice 400。
- 关联文档：[Hindsight Agent 记忆后端](./hindsight.md)。

## 2026-08-29

### 修复 home.activation 片段 `exit 0` 终止整个 HM 激活（artemis Nushell 启动报 job spawn unknown flag）

- 影响范围：所有加载 `home/base/core/git.nix` 的主机；直接症状为 artemis 上 `darwin-rebuild switch`
  后每次启动 Nushell 报 `The 'job spawn' command doesn't have flag '-t'`。
- 配置入口：`home/base/core/git.nix` （`home.activation.backupExistingGithubToken`）。
- 变更内容：该激活步骤在 `~/.config/agenix/github_token` 已是指向正确 agenix 路径的链接时执行
  `exit 0`。`home.activation` 片段被内联进激活脚本顶层， `exit` 会终止整个 Home
  Manager 激活，`checkLinkTargets`、文件链接等后续步骤全部跳过：系统闭包包含新 generation，但
  `~/.config/nushell/config.nu` 等文件停留在旧 generation。Nushell 因此加载到 atuin 18.12.1 生成的
  `job spawn -t atuin`（Nushell 0.113.1 已无 `-t` 标志）而报错。修复为用空命令（`:` +
  `elif`）跳过已就绪场景，不再终止激活。
- 验证方式：手动执行当前 generation 的
  `activate`（临时移走 token 链接绕过旧逻辑）后文件全部重新链接；`env ZELLIJ=1 INSIDE_EMACS=1 nu -c 'print "nushell config ok"'`
  通过；`nix eval .#evalTests` 通过；重新求值的激活片段中已无 `exit 0`。
- 关联文档：[Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)。

## 2026-08-29

### 修复 artemis（darwin）herdr 0.7.1 zig 构建缺少 macOS SDK

- 影响范围：artemis（aarch64-darwin）系统与 Home Manager 构建/切换。
- 配置入口：`lib/macosSystem.nix`（nixpkgs-darwin overlays 中的 `herdr` 覆盖）。
- 变更内容：herdr 0.7.1 的 zig 构建（vendored libghostty-vt）通过 `xcode-select --print-path` +
  `xcrun --sdk macosx --show-sdk-path` 探测 macOS SDK，但包定义 `nativeBuildInputs` 未含
  `cctools`/`xcbuild`，构建环境缺少这两个命令而失败（`DarwinSdkNotFound`）。overlay 补齐
  `cctools`、`xcbuild`、`apple-sdk_15` 并在 `preConfigure` 显式导出
  `DEVELOPER_DIR`/`SDKROOT`。注意必须用 `apple-sdk_15`：zig
  0.15.2 的 build 模式链接 build_runner 时与 SDK 26 的 `libSystem.tbd`
  不兼容（`undefined symbol: _getcwd/_sigaction/...`），SDK 15 实测正常。nixpkgs 升级到含 herdr
  0.8.2+（已补齐 cctools/xcbuild 依赖）后可移除该 overlay。
- 验证方式：`nix build .#darwinConfigurations.artemis.system` 完整成功；宿主环境用 SDK 26.4 复现
  `zig build` 失败、SDK 15.5 同例成功。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)。

## 2026-08-28

### 整合远端主线并保留 Syllune 语音输入

- 影响范围：`main` 分支、所有 Linux GUI 主机的语音输入与 Niri 配置。
- 配置入口：`flake.nix`、`flake.lock`、`home/linux/gui/base/voice-input.nix`、
  `home/linux/gui/niri/conf/keybindings.kdl`、`home/linux/gui/niri/conf/windowrules.kdl`。
- 变更内容：以远端 `1948b1cb` 为基线重放本地 9 个提交；保留 FlClash、Zen Browser、Homebrew
  nju 镜像与本地代理改动，撤销该提交中换回 Type4Me 的部分。最终继续使用 Syllune
  CPU 包、`eww-syllune-overlay` / `syllune-web` 服务与 Scroll Lock
  overlay 快捷键；同时将 FlClash 窗口规则中 Niri 26.04 不接受的行尾 `#` 注释改为独立 `//` 注释。
- 验证方式：`just test` = true；`niri 26.04 validate -c ~/.config/niri/config.kdl` =
  `config is valid`；Apollo Home Manager 服务求值含 `syllune-web`、`eww-syllune-overlay`，不含
  `type4me-linux`，Syllune ExecStart 解析到 `syllune-0.1.0`。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)、[应用版本审计](./application-version-audit.md)、
  [Niri 工作区与窗口分配](./niri-workspaces.md)。

### 添加 artemis（v2 macbook）SSH key 授权

- 影响范围：所有接入 `mainSshAuthorizedKeys` 的 PC、Macbook 与服务器。
- 配置入口：`vars/default.nix`（`mainSshAuthorizedKeys`）。
- 变更内容：新增 v2 macbook（macOS, artemis）的 ed25519 公钥，可 SSH 登录所有受管主机；注释区分旧
  `root@VitusMac` key 与新 `vitusartemis` key。
- 验证方式：`just test` = true（公钥主体不变，仅 SSH key comment 标签修正）。
- 关联文档：无（key 分发规则见 `vars/default.nix` 内注释）。

### 更新 syllune 锁到 1d249200（剪贴板注入保留原剪贴板）

- 影响范围：所有 Linux GUI 主机的 Syllune 语音输入。
- 配置入口：`flake.lock`（`syllune` 输入 `081d609` → `1d249200`）。
- 变更内容：上游新增
  `feat: 剪贴板注入保留原剪贴板 + paste_tool/focus_command 配置`。注入前备份并恢复原剪贴板内容，新增
  `paste_tool` / `focus_command` 配置项，剪贴板注入路径更可定制。
- 验证方式：`nix flake lock --update-input syllune` 已解析到 `1d249200`；`just test` = true。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### 代理客户端由 Clash Verge Rev 切换为 FlClash

- 影响范围：Linux GUI 主机（apollo/athena/generic）与 macOS（artemis）。
- 配置入口：`modules/nixos/desktop/networking/flclash.nix`（新增，删除原
  `clash-verge.nix`）、`home/linux/gui/niri/conf/windowrules.kdl`、`hosts/_shared/preservation.nix`、
  `modules/darwin/apps.nix`、`home/darwin/aerospace/aerospace.toml`。
- 变更内容：Clash Verge Rev 由 FlClash（`chen08209/FlClash`
  0.8.96，mihomo 内核）替代。官方 nixpkgs 无包、Homebrew 无 cask，Linux 侧用官方 AppImage
  `appimageTools.wrapType2` 打包（版本固定于 `flclash.nix`
  的 URL/hash），macOS 侧移除 cask 并改为注释说明手动安装官方 dmg。快捷键/窗口规则按 FlClash app-id
  `com.follow.clash` 更新；持久化保留
  `~/.local/share/com.follow.clash`。端口核对：FlClash 默认 mixed-port `7890`，与
  `home/darwin/proxy/proxychains.conf` 的 `socks5 127.0.0.1 7890` 一致，无需改端口。
- 验证方式：`curl` 实测 AppImage 下载与 sha256（61.8MB）写入
  `flclash.nix`；窗口规则与持久化条目静态核对；本次改动经 `nixfmt`/`prettier`
  及 apollo 配置求值验证（见文末条目）。
- 关联文档：[应用版本审计](./application-version-audit.md)、[Niri 工作区与窗口分配](./niri-workspaces.md)、
  [AeroSpace 使用指南](./aerospace-usage.md)。

### 浏览器统一为 Zen（移除 Firefox 与 Google Chrome）

- 影响范围：所有 Linux GUI 主机（apollo/athena/generic）与 macOS（artemis）。
- 配置入口：`home/linux/gui/base/browsers.nix`（移除 `nixpaks.firefox` 与
  `programs.google-chrome`）、删除 `hardening/nixpaks/firefox.nix` 并更新
  `hardening/nixpaks/default.nix`、`home/linux/gui/base/xdg/mime.nix`（`browser` 只留
  `zen.desktop`，编辑器保留 VSCode 的 `code*.desktop` 与 `vscode://` handler）、
  `home/linux/gui/base/xdg/autostart.nix`（浏览器自启动用 Zen desktop 文件）、
  `home/linux/gui/niri/conf/windowrules.kdl`（移除 firefox/google-chrome/chromium 规则）、
  `home/darwin/aerospace/aerospace.toml`（firefox/Chrome/Edge 规则移除，Zen 按 bundle id
  `app.zen-browser.zen` 进 `2Browser`）、`hosts/_shared/preservation.nix`（浏览器段改为 `.zen`）、
  `modules/darwin/apps.nix`（casks 移除 `firefox`/`google-chrome`）。
- 变更内容：浏览器统一为 Zen（Linux 走 `youwen5/zen-browser-flake`，macOS 用 Homebrew cask
  `zen`）；Firefox（含 NixPak 沙箱）与 Google Chrome/Chromium 移除。
- 验证方式：改动文件经 `nixfmt`/`prettier`
  检查；apollo 配置求值不再含 vscode 之外的浏览器包；`niri validate` 未受窗口规则删除影响。
- 关联文档：[Zen Browser](./zen-browser.md)、[应用版本审计](./application-version-audit.md)、
  [Niri 工作区与窗口分配](./niri-workspaces.md)、[AeroSpace 使用指南](./aerospace-usage.md)。

### 语音输入由 Syllune 换回 Type4Me（同日整合时已撤销）

- 影响范围：Linux GUI 主机（apollo/athena/generic）。
- 配置入口：`flake.nix`（input `syllune` →
  `type4me`）、`flake.lock`（syllune 节点替换为 type4me 节点，沿用远端基线其余锁定）、`home/linux/gui/base/voice-input.nix`（Type4Me 版）、
  `home/linux/gui/niri/conf/keybindings.kdl`、`documents/linux-voice-input.md`。
- 变更内容：语音输入方案从 Syllune 换回 Type4Me（`github:Vitus213/type4me-linux` 固定
  `3e367432036bbbbb035dbaa6229ecb3ce94ee2d8`，该仓库 main 已演进为 Syllune，故按提交锁定 Type4Me 版）。服务为
  `type4me-linux.service`（`type4me-linux service`）；快捷键为 `Scroll Lock` → D-Bus
  `Type4Me.Controller.Toggle`、`Shift+Scroll Lock` → `Controller.Cancel`。移除 eww overlay 依赖。
- 验证方式：`nix eval` 反映 `type4me-linux` 服务与 `type4me` input；详情见
  [Linux 语音输入](./linux-voice-input.md)。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)、[应用版本审计](./application-version-audit.md)。
- 当前状态：本条仅记录远端 `1948b1cb` 的中间状态；同日整合后当前配置仍为 Syllune，Type4Me
  input 与服务均已移除。

### Homebrew 镜像切至南京大学（nju）并启用本地代理链路

- 影响范围：macOS（artemis）上 Homebrew 的 git 源、bottle/API 与 pip 索引，以及 darwin
  activation 阶段 `brew bundle` 与本机手动 `brew install`。
- 配置入口：`modules/darwin/apps.nix` 的 `homebrew_mirror_env` 与 `local_proxy_env`。
- 变更内容：`mirrors.tuna.tsinghua.edu.cn` 与 `mirrors.bfsu.edu.cn` 的
  `homebrew-bottles`（API/bottle）、`git/homebrew`（brew/homebrew-core）及 pypi 端点自 2026-08 起实测均返回 403，不可用；整体切至 nju（`mirror.nju.edu.cn`，bottles/git/pypi 各端点实测 200）。本地代理走 FlClash
  mixed-port `http://127.0.0.1:7890`（与 proxychains 配置一致），随 `homebrew_env_script`
  注入 activation 会话。
- 验证方式：`curl` 实测 nju 各端点 200；`brew install` 手动验证见本机；配置求值经 `nixfmt` 检查。
- 关联文档：无（tuna/bfsu 失效旧值保留在配置注释中，便于回滚）。

### 仓库恢复 git 关联并重放本地修改

- 影响范围：仓库整体。
- 变更内容：`~/nix-config` 在恢复时丢失 `.git`，本次重新 `git init` 并以
  `git@github.com:Vitus213/nix-config` 为 `origin`（HTTPS 可达），以远端 `main`
  （`65f32740`，含 Syllune/Sioyek/壁纸等演进）为基线重建工作区，将本地存在的 FlClash、Type4Me 换回、浏览器精简与本轮 Homebrew 修改重放其上；VSCode 按用户要求保留安装（Linux
  `programs.vscode`、macOS cask `visual-studio-code` 与 catppuccin-vscode 扩展均保留）。
- 验证方式：`git fetch`/`git log` 核对远端基线；改动文件 `nixfmt`/`prettier`
  检查；apollo 配置求值（见文末）。

## 2026-08-17

### 更新 syllune 锁到 081d609（X11 剪贴板注入 schema）

- 影响范围：所有 Linux GUI 主机的 Syllune 语音输入。
- 配置入口：`flake.lock`（`syllune` 输入 `0c35b8e` → `081d609`）。
- 变更内容：旧锁的 `[inject]` schema 不识别 `~/.config/syllune/config.toml` 的 `paste_command` /
  `x11_clipboard_command`，`syllune stream`
  直接退出，语音输入不可用。syllune 上游推送新 schema（X11 剪贴板注入、processing
  api_key/prompt 入配置、asr 可选字段，CPU 栈测试全绿）后更新锁。
- 验证方式：`nix flake lock --update-input syllune` 成功；`nix eval .#evalTests` =
  true；apollo 切换后 `syllune stream` 输出 `{"type":"ready"}`，不再报 unknown configuration
  field。本机另清理了 `nix profile` 里两个手工安装的旧 syllune 条目（shadow
  PATH，挡住 HM 新版）；新主机不受影响。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### 修复 voice-input 裸 python3 与 editors python env 的 buildEnv 冲突

- 影响范围：所有 Linux GUI 主机（apollo/athena/generic）的 `home-manager-path` 构建。
- 配置入口：`home/linux/gui/base/voice-input.nix`。
- 变更内容：`65f32740` 引入的裸 `pkgs.python3` 与 editors 的 `python313.withPackages` env 在
  `home-manager-path` buildEnv 中撞
  `bin/python3-config`，导致 toplevel 构建失败。将 voice-input 的裸 `pkgs.python3` 包为
  `lib.lowPrio`，冲突时让位给 editors 的完整 python env（功能超集）；overlay
  pump 只需 PATH 上有任意 python3，行为不变。
- 验证方式：`nix eval .#evalTests` =
  true；`nix build .#nixosConfigurations.apollo.config.system.build.toplevel` 通过。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### Sioyek 强制 xcb 平台（Qt6 wayland + NVIDIA EGL 不兼容）

- 影响范围：所有 Linux GUI 主机（apollo/athena/generic）的 Sioyek 启动方式。
- 配置入口：`home/linux/gui/base/media.nix`。
- 变更内容：Qt6.11 wayland 平台在 NVIDIA 驱动下 `QOpenGLWidget`
  建 EGL 上下文失败（`EGL_BAD_MATCH 3009`），sioyek 窗口永不 commit、niri 不显示窗口；xcb 路径实测正常。用
  `symlinkJoin` + `wrapProgram` 以同名 wrapper 安装 sioyek 并
  `--set QT_QPA_PLATFORM xcb`，走 XWayland；desktop/xdg-open 的 PATH 解析同样命中 wrapper。2026-08-16「PDF 默认查看器」条目中「Qt 走 Wayland」的描述以此为准。
- 验证方式：apollo 实测 `sioyek /tmp/...pdf` 1-2 秒内窗口出现并钉到
  `9file`，渲染、状态栏正常；`xdg-mime query default application/pdf` = `sioyek.desktop`。
- 关联文档：[应用版本审计](./application-version-audit.md)。

### eww overlay 服务改前台运行

- 影响范围：所有 Linux GUI 主机的 `eww-syllune-overlay.service`。
- 配置入口：`home/linux/gui/base/voice-input.nix`。
- 变更内容：`eww daemon` 默认 fork 后台化，父进程退出使 systemd `Type=simple`
  误判服务已死（`is-active` 恒为 inactive，`Restart=on-failure` 失效）；改为 `daemon --no-daemonize`
  前台运行。
- 验证方式：apollo 实测切换后 `systemctl --user is-active eww-syllune-overlay` = active，进程为前台
  `eww daemon --no-daemonize`。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

## 2026-08-16

### 语音输入由 Type4Me 切换为 Syllune（远程 flake）

- 影响范围：所有 Linux
  GUI 主机（apollo/athena/generic）的语音输入栈；Type4Me 包、服务与 flake 输入一并移除，不再保留后备。
- 配置入口：`flake.nix`（`type4me-linux` 输入换为 `github:Vitus213/syllune`，锁定
  `0c35b8e`，`inputs.nixpkgs` 不跟随主仓库）、`home/linux/gui/base/voice-input.nix`。
- 变更内容：Syllune 是 Rust 实时语音输入工具；当前配置走云端链路——流式 ASR 用 DashScope
  `qwen3-asr-flash-realtime`，文本整理走 OpenAI 兼容接口调
  `qwen-flash`，本地 sherpa-onnx 后端未启用，故安装不带 CUDA 工具链的 `syllune-cpu`
  包。Syllune 替代 Type4Me 成为 Niri 唯一全局语音输入。 `voice-input.nix` 改为安装 Syllune
  flake 包、`eww`、`python3`，声明 `eww-syllune-overlay.service`（overlay pill）与
  `syllune-web.service`（历史记录控制台，`127.0.0.1:8790`）。Niri `Scroll_Lock` / `Ctrl+Scroll_Lock`
  绑定指向 `~/.config/eww/syllune-overlay-toggle`
  overlay 脚本（独立仓库，不由本配置管理，新主机需手动克隆）。
- 验证方式：`nixfmt --check` 通过；`nix eval .#evalTests` = true；apollo 求值实测服务集合含
  `syllune-web`、`eww-syllune-overlay` 且不含 `type4me-linux`；`nix build` 通过 syllune
  flake 输入构建 Syllune CPU 包成功。未执行 `just local` 或系统切换。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)、[应用版本审计](./application-version-audit.md)。

### PDF 默认查看器由浏览器切换为 Sioyek

- 影响范围：所有 Linux GUI 主机（apollo/athena/generic）的 `application/pdf` 默认打开方式。
- 配置入口：`home/linux/gui/base/media.nix`（安装 `pkgs.sioyek`）、
  `home/linux/gui/base/xdg/mime.nix`（`application/pdf` 默认改为 `sioyek.desktop`，移除原
  `# TODO: pdf viewer`）、`home/linux/gui/niri/conf/windowrules.kdl`（Sioyek 钉到 `9file`）。
- 变更内容：浏览器看 PDF 偏重且无阅读位点/笔记；Sioyek 键盘驱动、平滑滚动、Qt 走 Wayland，与现有 nvim/yazi 风格一致。目录默认保持 yazi 不变。
- 验证方式：`nixfmt --check` 通过；`nix eval .#evalTests` = true；apollo 求值实测 `home.packages` 含
  `sioyek-2.0.0-unstable`、`xdg.mimeApps` 的 `application/pdf` 为
  `["sioyek.desktop"]`；`niri validate` 通过。未执行 `just local`。
- 关联文档：[Niri 工作区与窗口分配](./niri-workspaces.md)、[应用版本审计](./application-version-audit.md)。

### Syllune 语音输入快捷键改为 Scroll_Lock / Ctrl+Scroll_Lock

- 影响范围：Linux GUI 主机的 Syllune 语音输入覆盖层触发方式。
- 配置入口：`home/linux/gui/niri/conf/keybindings.kdl`。
- 变更内容：`Scroll_Lock` 触发语音输入（`syllune-overlay-toggle`），`Ctrl+Scroll_Lock`
  触发语音整理（`syllune-overlay-toggle prompt-optimize`），替代原 `Scroll_Lock` /
  `Shift+Scroll_Lock` 方案，均为独立按键、不占用滚轮。
- 验证方式：`niri validate` 通过，`niri msg action load-config-file` 热重载成功。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### 回滚飞书共享的无效 NVIDIA 修复并如实记录上游限制

- 影响范围：所有 Linux GUI 主机的飞书屏幕共享配置与文档。
- 配置入口：`home/linux/gui/niri/conf/config.kdl`、`home/linux/gui/niri/default.nix` （移除
  `debug-nvidia.kdl` 的 include 与链接）、`documents/wayland-screen-sharing.md`。
- 变更内容：回滚
  `debug { force-pipewire-invalid-modifier; }`（真实会议复测证伪：只改 modifier 不改缓冲类型，协商仍报
  `no more input formats`，且可能拖累 OBS）。pw-mon 抓取 PipeWire 协商确认根因：niri 只发布 DMA-BUF，飞书（X11 强制，`--ozone-platform=wayland`
  与 `NIXOS_OZONE_WL=1` 均不生效）不能导入 DMA-BUF，交集为空；属上游限制，配置无法绕过。保留
  `WebRTCPipeWireCapturer`（portal 捕获前提，对 Zen/Chromium 有效）。替代方案：Zen 网页版会议共享或 OBS 推流。
- 验证方式：`niri validate` 通过；pw-mon 实测提供方/消费方格式与
  `window.x11.display=:0`；对照 OBS/Zen 同提供方共享正常。
- 关联文档：[Wayland 屏幕共享](./wayland-screen-sharing.md)。

### 修复 Niri 下飞书屏幕共享黑屏并验证 portal 链路

- 影响范围：所有 Linux
  GUI 主机（apollo/athena/generic）的飞书屏幕共享；OBS 与腾讯会议配置不变，仅补充已验证的正确入口和对照方式。
- 配置入口：`home/linux/gui/base/misc.nix`（`pkgs.feishu` 加入
  `WebRTCPipeWireCapturer`）、`documents/wayland-screen-sharing.md`、`documents/linux-im-apps.md`、`documents/tencent-meeting.md`、`documents/application-version-audit.md`。
- 变更内容：ASHPD 与 OBS 实测证明当前 D-Bus、portal-gnome、Niri
  ScreenCast、PipeWire、NVIDIA 链路可建立实时流，不替换 portal；飞书保持 XWayland，只把捕获后端切到 portal/PipeWire。腾讯会议保留包含完整上游修复的默认
  `wemeet`，`wemeet-xwayland` 继续作为会议内对照入口。
- 验证方式：飞书同包 Chromium
  A/B 实测无参数时整屏缩略图黑屏、加参数后 portal 返回实时画面；覆盖后的 Feishu `7.66.10`
  构建成功，产物 wrapper 与运行时命令行均含该参数且窗口仍为 XWayland；OBS `32.1.2`
  实测 PipeWire 流为 BGRx 2560×1440、状态 `streaming`；`nix eval .#evalTests` =
  true，apollo/athena/generic 三主机完整求值通过。未执行 `just local`
  或系统切换；飞书/腾讯会议真实会议仍需登录后确认远端画面。
- 关联文档：[Wayland 屏幕共享](./wayland-screen-sharing.md)、[Linux 微信、QQ 与飞书](./linux-im-apps.md)、[Linux 腾讯会议](./tencent-meeting.md)。

### 为契合 Wayland 将截图/办公/笔记组件替换为开源版

- 影响范围：所有 Linux
  GUI 主机（apollo/athena/generic）的截图链、办公套件与 Markdown 笔记；macOS（artemis）不受影响。
- 配置入口：`home/linux/gui/base/desktop-tools.nix`（`flameshot`/`hyprshot` →
  `grim`/`slurp`/`satty`）、`home/linux/gui/base/editors.nix`（`wpsoffice-cn` →
  `libreoffice-fresh`）、`home/linux/gui/base/note-taking.nix`（`typora` →
  `apostrophe`）、`home/linux/gui/base/xdg/autostart.nix`（autostart 条目同步）、
  `home/linux/gui/niri/conf/windowrules.kdl`（`title="^Typora"` 规则换为
  `app-id="org.gnome.gitlab.somas.Apostrophe"`）。
- 变更内容：hyprshot 依赖 hyprctl，实测在 niri 下不可用；flameshot 在 niri 上多屏截图与标注有已知问题；grim 在本机 niri 实测截屏正常，故截图链换为 Wayland 原生 grim（截图）+
  slurp（选区）+
  satty（标注），基础全屏/窗口截图继续用 niri 内置 Print 键。办公套件由闭源 WPS 换为开源 LibreOffice
  Fresh（GTK/KDE Wayland 原生）。笔记由闭源 Typora 换为 Apostrophe（GTK4、Wayland 原生）。
- 验证方式：`nixfmt --check` 改动文件通过；`nix eval .#evalTests` =
  true；apollo/athena/generic三主机求值实测 `home.packages` 含
  `apostrophe-3.4`、`grim-1.5.0`、`slurp-1.5.0`、`satty-0.21.1`、
  `libreoffice-26.2.1.2`，且不再含 typora/wpsoffice/flameshot/hyprshot；apostrophe
  desktop 文件确认存在（`org.gnome.gitlab.somas.Apostrophe.desktop`）。未执行 `just local`
  或系统切换。
- 关联文档：[Niri 工作区与窗口分配](./niri-workspaces.md)、[应用版本审计](./application-version-audit.md)。

## 2026-08-15

### 登录自启动浏览器切换为 Zen Browser

- 影响范围：所有 Linux
  GUI 主机（apollo/athena/generic）；登录 Niri 会话后自动启动的浏览器由 Firefox 改为 Zen。Firefox 保留安装，仅不再自启动。
- 配置入口：`home/linux/gui/base/xdg/autostart.nix`（`xdg.autostart.entries` 浏览器条目由
  `nixpaks.firefox` 换为 Zen flake input 提供的 `zen.desktop`，函数参数新增 `zen-browser`）。
- 变更内容：承接「默认浏览器切换为 Zen
  Browser」——默认浏览器（MIME/`$BROWSER`）已切换，登录自启动仍是 Firefox，本次统一为 Zen。`Exec=zen --name zen %U`，zen 二进制在用户 profile
  PATH；Niri `app-id="zen"` 规则继续钉到 `2browser` 工作区。
- 验证方式：`nixfmt --check` 通过；`nix eval .#evalTests` =
  true；apollo/athena/generic 三主机完整求值无警告；求值实测 autostart 列表含
  `zen.desktop`（1.21.14b）且不含 Firefox。未执行 `just local` 或系统切换。
- 关联文档：[Zen Browser](./zen-browser.md)。

### 在 bailian provider 新增 DeepSeek V4 Pro 0813 并切换 slow/plan 角色

- 影响范围：用户级 OMP 模型 catalog 与模型角色；`slow`、`plan` 角色由 `bailian/qwen3.8-max:max`
  切换为 `bailian/deepseek-v4-pro-0813:max`，其余角色不变（advisor/review 仍为
  `bailian/qwen3.8-max:max`、smol 仍为 `bailian/deepseek-v4-flash-0731:max`）。`bailian/*`
  的 fallback 链仍指向 `scitrace/gpt-5.6-sol`。
- 配置入口：`~/.omp/agent/models.yml`、`~/.omp/agent/config.yml`。
- 变更内容：在 `bailian` provider 下新增
  `deepseek-v4-pro-0813`（上下文 1M、输出上限 393K、思考力度 high/max，compat 参数与既有
  `deepseek-v4-pro` 一致：`thinking.type=enabled`、 `reasoning_content`
  字段、工具调用需保留 reasoning/assistant 内容）；`modelRoles` 的 `slow` 与 `plan`
  切换到该模型。需求中提到的 `deepseek-v4-pro-0831` 在百炼不存在（`/v1/models` 无此 id，直接调用返回
  `model_not_found`），现存最接近的带日期快照为 `0813`；裸别名 `deepseek-v4-pro`
  此前已配置，指向最新 pro 快照。
- 验证方式：curl 调用百炼 `chat/completions` 确认 `deepseek-v4-pro-0813` 正常返回（含
  `reasoning_content`）；`omp models bailian` 显示新模型（1M / 393K，efforts high,max）；
  `omp --model bailian/deepseek-v4-pro-0813 --thinking low --no-tools --no-session -p "只输出 OK"`
  成功；`omp config get modelRoles --json` 确认 slow/plan 已指向新模型。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)。

### 修复配置审计发现的缺陷（MIME/ssh/GTK 警告）+ 补测试

- 影响范围：所有 Linux 主机；其中 ssh 行为变更仅影响 generic（`192.168.*`
  homelab 块此前声称已删除、实际仍被渲染，本次真正移除）。
- 配置入口：`home/linux/gui/base/xdg/mime.nix`、`home/base/tui/ssh.nix`（新增
  `modules.ssh.homelab.enable` 选项，默认 true）、`hosts/olympians-generic/home.nix`、
  `home/base/core/theme.nix`、`outputs/x86_64-linux/tests/home-manager/`。
- 变更内容：
  1. `x-scheme-handler/tg`
     的 desktop 文件名删除尾随空格（`org.telegram.desktop.desktop `）；该空格此前已写入部署的
     `mimeapps.list`，严格解析器可能匹配失败。
  2. generic 主机删除 homelab `192.168.*` ssh 块：此前用 `programs.ssh.matchBlocks`
     mkForce 覆盖，但基模块声明在 `programs.ssh.settings`
     下，覆盖对象错误从未生效（生成的 config 仍含指向 `/etc/agenix/ssh-key-romantic` 的块）；且
     `mkForce {}` 只清空块内容、仍残留空 `Host` 头，故改为基模块新增声明式开关
     `modules.ssh.homelab.enable`，generic 置 false，该键整体不渲染。
  3. `theme.nix` 显式 `gtk4.theme = null`，消除新版 home-manager 关于 `gtk.theme`
     隐式传播的弃用警告（GUI 链 `gtk.nix` 已有同值，hermes TUI 链缺失）。
- 验证方式：`nixfmt --check` 改动文件通过；`nix eval .#evalTests` =
  true（home-manager 测试扩至四主机并新增 `sshHasHomelabBlock`
  断言，generic=false/其余=true）；四主机完整求值均无弃用警告；构建产物实测generic 的
  `~/.ssh/config` 无 `192.168.*` 块、apollo 的 `mimeapps.list`
  `x-scheme-handler/tg=org.telegram.desktop.desktop`（无尾随空格）。未执行 `just local` 或系统切换。
- 关联文档：[通用 NixOS 桌面 Host](./generic-nixos-host.md)。

### 默认浏览器切换为 Zen Browser

- 影响范围：所有加载 `home/linux/gui`
  链的主机（apollo/athena/generic）；`xdg-open`/portal 打开的 http(s) 与 html/pdf/json 等类型、以及读取
  `$BROWSER` 的 CLI 程序均改用 Zen。Firefox/Chrome 保留安装并作为回退。
- 配置入口：`home/linux/gui/base/xdg/mime.nix`（`browser` 列表首位改为
  `zen.desktop`）、`home/linux/base/shell.nix`（`BROWSER` 改为 `zen`）。
- 变更内容：此前 MIME 默认浏览器为 Firefox、`BROWSER=firefox`（Zen 加装时有意未切换），本次正式切换。`mime.nix`
  强制写入 `mimeapps.list`（`force = true`），运行时 `xdg-mime default`
  的临时修改会被下次部署覆盖，故必须走声明式配置。
- 验证方式：`nixfmt --check`、`nix eval .#evalTests` 通过；apollo toplevel完整求值通过。未执行
  `just local` 或系统切换；部署后可用 `xdg-mime query default x-scheme-handler/https` 确认输出
  `zen.desktop`。
- 关联文档：[Zen Browser](./zen-browser.md)。

### 回滚游戏栈与雷神加速器（不再安装）

- 影响范围：apollo 移除 Steam/Proton/gamemode/lutris 等；路由器移除雷神插件、UOnP、apollo 白名单与静态租约。OpenClash
  fake-ip 及其既有游戏域名隔离规则保持原样。
- 配置入口：`modules/nixos/desktop/gaming.nix`、`home/linux/gui/base/gaming.nix`（删除）、
  `outputs/x86_64-linux/src/olympians-apollo.nix`、路由器侧（官方卸载脚本 + apk del +
  hook 备份恢复）。
- 变更内容：删除两个 gaming 模块与 apollo 的 `gaming.enable`；路由器卸载雷神、禁用 UOnP、恢复
  `openclash_custom_firewall_rules.sh`
  备份、删 apollo 静态租约。原因：Apex 截至 2026-08 仍被 EA 反作弊封锁（E111000B），本机游戏栈无实际用途。
- 验证方式：`nix eval .#evalTests` 通过；路由器无 leigod 进程/目录/init、nft 无 148 规则、upnpd
  STOPPED、手机静态租约（.115）保留。

### 雷神加速器与 OpenClash fake-ip 共存（路由器侧，apollo 加入游戏白名单）

- 影响范围：路由器（192.168.100.1）防火墙/UPnP/dhcp；apollo 的游戏 UDP 绕过 OpenClash 交给雷神，其余设备继续 fake-ip。
- 配置入口：路由器
  `/etc/openclash/custom/openclash_custom_firewall_rules.sh`（白名单加 192.168.100.148）、dhcp 静态租约（apollo
  MAC→148）、`upnpd.config.enabled=1`；雷神官方路由器插件 + apk 补依赖（ImmortalWrt
  25.12 无 opkg）。
- 变更内容：复用既有四层隔离（游戏域名国内 DNS / fake-ip 过滤 / Clash DIRECT /
  UDP 旁路），仅把 apollo 加入第 4 层白名单并做静态租约；启用 UOnP 供雷神 App 发现设备。
- 验证方式：apollo 上 ea.com/playapex.com 解析为真实 IP、google.com 仍 198.18.x；nft
  openclash_mangle 含 148 的 return 规则且有命中计数。
- 回滚与详情：`~/work/all_server/leigod-openclash-gaming.md`（含 hook 备份 `.bak-20260815-apollo`
  与全量回滚步骤）；SERVERS.md 已同步。

### 文件管理器由 Thunar 切换为 Dolphin（Kvantum Catppuccin 主题）

- 影响范围：所有加载 `modules/nixos/desktop`
  的 NixOS 桌面（apollo/athena/generic）；Thunar（GTK/X11 时代，niri 下走 XWayland，4K 分数缩放模糊）被完全移除。
- 配置入口：`modules/nixos/desktop/misc.nix`（`programs.thunar` 删除， `environment.systemPackages`
  加入 `kdePackages.dolphin` + `kdePackages.ark`）、
  `home/linux/gui/niri/conf/windowrules.kdl`（app-id 钉 `org.kde.dolphin`，仍走 `9file`
  工作区）、`home/linux/gui/base/kde-theme.nix`（新增：Kvantum 引擎 + Catppuccin Mocha/Pink 主题 +
  kdeglobals 图标）、`home/linux/gui/base/desktop-tools.nix` （新增
  `QT_STYLE_OVERRIDE=kvantum`、`GSK_RENDERER=gl`、`GTK_THEME`）、 `home/base/core/theme.nix`（新增
  `gtk.theme`）、`README.md`、`documents/niri-workspaces.md`。
- 变更内容：最终选 Dolphin（冷启动 16ms vs Nautilus
  2338ms，实测 146 倍；KIO 异步 I/O；分栏/内嵌终端/批量重命名）。主题链：`kdePackages.qtstyleplugin-kvantum`
  引擎 + `catppuccin-kvantum`（mocha/pink）主题放
  `~/.config/Kvantum/`（catppuccin/nix 官方布局），图标用已安装的 Catppuccin 重着色 Papirus。`QT_STYLE_OVERRIDE=kvantum`
  必需（kdeglobals widgetStyle 在非 Plasma 环境不生效）。GTK 侧同步补齐： `gtk.theme` =
  `catppuccin-gtk`（mocha/pink/rimless）保护 foliate/remmina/wlogout 等 GTK 应用；`GSK_RENDERER=gl`
  修 NVIDIA 上 GTK4 Vulkan 崩溃（实测 `VK_ERROR_OUT_OF_DATE_KHR`）。中途试跑过 Nautilus 与 COSMIC
  files：Nautilus 需 NVIDIA 补丁且启动慢，COSMIC
  files 在 niri 下功能残缺，均弃。终端侧 yazi（`yy`）与 `inode/directory` MIME 绑定不变。
- 已知限制：非 Plasma 环境下 KColorScheme 不加载 .colors 文件，Dolphin 文件视图文字对比度偏低（深灰文字于深蓝底）；Kvantum
  chrome 与图标正常。属 KDE 色彩框架在非 Plasma 会话的已知深坑，未继续硬修。
- 验证方式：Dolphin 实机试跑截图确认深色 Mocha 背景 + Kvantum
  chrome + 粉色文件夹图标生效；`nixfmt --check`、`nix eval .#evalTests`、apollo
  toplevel 完整求值通过；未执行 `just local` 或系统切换。
- 关联文档：[Niri 工作区与窗口分配](./niri-workspaces.md)、[应用版本审计](./application-version-audit.md)。

### 重建精简游戏栈并在 apollo 启用（Overwatch 等；Apex 仍被 EA 封锁）

- 影响范围：apollo 主机新增 Steam/Proton/gamescope/gamemode/lutris/mangohud 等；athena/generic 不受影响（模块仍按主机 opt-in）。
- 配置入口：`modules/nixos/desktop/gaming.nix`、`home/linux/gui/base/gaming.nix`、
  `outputs/x86_64-linux/src/olympians-apollo.nix`。
- 变更内容：重写两个 gaming 模块——只保留 Steam/Proton/gamemode/gamescope/lutris/
  mangohud 核心，移除 aagl/nix-gaming 依赖（不再需要 mihoyo 启动器）；apollo 两侧
  `modules.desktop.gaming.enable = true`。
- 事实更正（2026-08-15 实测）：Apex
  Legends 仍对 Linux/Proton 返回 E111000B 封锁，2026-06 的"重新生效"为短暂窗口，本条目此前"Apex 可直接进游戏"的表述作废；Overwatch
  2（BattlEye 已支持 Proton）等不受影响。Apex 在 NixOS 上只能走云游戏（GeForce NOW）或等 EA 解禁。
- 验证方式：`nix eval .#nixosConfigurations.apollo.config.programs.steam.enable` =
  true、gamemode/lutris 均 true；`nix eval .#evalTests` 通过。未执行系统切换。

### 加装 Zen Browser（垂直标签栏浏览器，Wayland 原生）

- 影响范围：所有加载 `home/linux/gui`
  链的主机（apollo/athena/generic）的浏览器栈；新增并存浏览器，不替换现有 Firefox/Chrome，MIME 默认浏览器仍为 Firefox。
- 配置入口：`flake.nix`（新增 `zen-browser` flake input）、
  `home/linux/gui/base/browsers.nix`（`home.packages` 加入
  `zen-browser.packages.<system>.default`）、
  `home/linux/gui/niri/conf/windowrules.kdl`（`app-id="zen"` 钉到 `2browser` 工作区）。
- 变更内容：加装 Zen Browser `1.21.14b`（Firefox 开源分支，默认左侧垂直标签栏，Workspaces/Split
  View/Compact Mode 面向超多标签场景），版本来源
  `github:youwen5/zen-browser-flake`（上游每日自动跟随 Zen 发布），固定于
  `flake.lock`。未套 NixPak，与 Chrome 的处理一致；uBlock Origin 等扩展待首次启动后手动安装。
- 验证方式：apollo 主机完整求值到 toplevel drvPath 通过； `nix build` 实测构建
  `zen-browser-1.21.14b` 成功，desktop 文件确认 Wayland app-id 为 `zen`；`nix eval .#evalTests` 与
  `nixfmt --check` 通过。未执行 `just local` 或系统切换；实际使用体验待部署后确认。
- 关联文档：[Zen Browser](./zen-browser.md)、[应用版本审计](./application-version-audit.md)。

### 移除游戏栈（不在 NixOS 上打游戏）

- 影响范围：所有 Linux 桌面主机的 flake inputs 与桌面模块；gaming 此前全部 `enable = false`，但
  `gaming.nix` 顶部无条件 import
  nix-gaming/aagl 模块，aagl 不跟随 nixpkgs 会独立 eval 一份，属纯开销。
- 配置入口：`flake.nix`、`modules/nixos/desktop/gaming.nix`、`home/linux/gui/base/gaming.nix`、
  `outputs/x86_64-linux/src/olympians-*.nix`。
- 变更内容：删除 `nix-gaming`/`aagl` inputs 与两个 gaming 模块，清理三个 src 文件的
  `modules.desktop.gaming.enable = false`；同步 README 与 application-version-audit。
- 验证方式：三个 src 文件 `nix-instantiate --parse` 通过；`nix eval .#evalTests`
  通过；flake.lock 修剪 aagl/nix-gaming。未执行系统切换。

### 移除未使用的 swaylock

- 影响范围：所有 Linux GUI 主机的用户包与 Wayland PAM 服务。
- 配置入口：`home/linux/gui/base/desktop-tools.nix`、`modules/nixos/desktop.nix`。
- 变更内容：删除 `programs.swaylock.enable` 与对应
  `security.pam.services.swaylock`。锁屏链路实际走 noctalia-shell 内置
  `WlSessionLock`，全仓库无任何 swaylock 调用路径，属死重。
- 验证方式：`nix-instantiate --parse` 与 `nix eval .#evalTests` 通过；未执行系统切换。
- 关联文档：[Noctalia 锁屏解锁延迟修复](./lockscreen-pam.md)。

### Noctalia 锁屏解锁延迟修复（专用 PAM 服务 + 降哈希成本）

- 影响范围：所有加载 `modules/nixos/desktop`
  的 NixOS 桌面（apollo/athena/generic）上 noctalia-shell 的锁屏认证行为；解锁耗时从实测约 10 秒降至预期约 0.1 秒。
- 配置入口：`modules/nixos/desktop/security.nix`（新增
  `security.pam.services.noctalia-lock`）、`home/linux/gui/base/noctalia/default.nix`
  （noctalia-shell.service 注入 `NOCTALIA_PAM_SERVICE=noctalia-lock`）、
  `vars/default.nix`（`initialHashedPassword`）、
  `outputs/x86_64-linux/tests/lockscreen-pam/`（回归测试）。
- 变更内容：锁屏认证从完整 `login` PAM 栈（unix-early nullok 探测 3.5s +
  gnome-keyring 解密 ~3s + 多次 pam_unix 验证）切换到专用精简栈（单次 pam_unix 校验）。锁屏不再顺带解锁 gnome-keyring；greetd 登录时已解锁，会话内不受影响。
  `initialHashedPassword` 由 scrypt rounds=11 换成 yescrypt 默认 rounds（`mkpasswd -m yescrypt -s`
  生成并经 crypt 往返校验），单次验证 1741ms → 17ms。
- 验证方式：`nix eval .#evalTests`（含新回归测试）通过；错误密码结构测试显示 Password 提示从 T+3536ms 提前到 T+1ms；新哈希单次验证实测 17ms。未执行
  `just local` 或系统切换；实测解锁效果待部署后确认。
- 关联文档：[Noctalia 锁屏解锁延迟修复](./lockscreen-pam.md)。

### 将 Oh My Pi（omp）从用户级 Bun 迁移到官方 flake

- 影响范围：所有加载 `home/base/core` 的主机（apollo/athena/generic/artemis/hermes）上的 `omp`
  安装方式与版本来源；移除临时 Bun overlay 与对应 shell PATH 补丁。
- 配置入口：`flake.nix`（新增 `omp` input）、`home/base/core/omp.nix`（启用
  `programs.omp.enable`）、`home/base/core/npm.nix`、`home/base/core/shells/default.nix`、
  `home/base/core/shells/config.nu`。
- 变更内容：删除 `overlays/bun/default.nix`（nixpkgs 仍为 bun 1.3.13，omp 已不再依赖系统 Bun）与对应
  `outputs/x86_64-linux/tests/bun`、`nushell-bun-path` eval test；移除
  `~/.bun/bin`、`~/.cache/.bun/bin` PATH 条目与 `home.packages` 中的 `bun`；OMP 改为官方 flake
  `can1357/oh-my-pi` 源码构建（当前 `17.3.4`），版本固定于 `flake.lock`。
  `~/.omp/agent/config.yml`、`models.yml` 仍为用户级文件，手工维护。
- 验证方式：`nixfmt --check`、`nix eval .#evalTests` 通过； `nix eval` 确认 apollo HM 中
  `programs.omp.enable = true`、`pkgs.bun` 回落至 `1.3.13`；
  `nix build github:can1357/oh-my-pi#default` 构建并运行 `omp --version`
  验证（构建耗时较长，官方无二进制缓存）。
- 关联文档：[Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)、[应用版本审计](./application-version-audit.md)。

### 主机共享模块与仓库清理（W1 + W2）

- 影响范围：全部主机（apollo/athena/generic/artemis/hermes）的构建组织方式与 flake
  inputs；35 项关键配置属性语义快照对比零差异，行为不变。
- 配置入口：`hosts/_shared/`（preservation/nvidia/netdev-mount 共享模块）、
  `modules/nixos/base/zram.nix`、`modules/nixos/desktop/power.nix`、
  `modules/nixos/desktop/networking/remote-desktop.nix`（mkDefault 化）、
  `lib/macosSystem.nix`（darwin overlay 单一来源）、`Justfile`（`up-nix` 修复）。
- 变更内容：删除 6 个无引用 flake
  inputs 与 lock 修剪；删除无主机导入的 secureboot/重复 preservation/nvidia 副本、空 aarch64-linux
  outputs、server/KubeVirt/K3s/colmena 死代码与 Justfile 对应命令组；主机层样板去重并消除 mkForce；home/linux 入口链式化；src 文件幽灵参数清理。
- 验证方式：`nix eval .#evalTests` 通过；变更前后语义快照逐项对比零差异；hermes drvPath 不变；未执行
  `just local` 或系统切换。
- 关联文档：[主机共享模块与仓库清理](./host-shared-modules.md)。

### 开启 Herdr 后台通知与 OMP Agent 集成

- 影响范围：全部加载共享 TUI Home
  Manager 配置的 Linux 与 macOS 主机上的 Herdr 通知行为；apollo 上已运行的 Herdr `0.7.1`
  server 已同步生效。
- 配置入口：`home/base/tui/dev-tools.nix`；用户级集成文件
  `~/.omp/agent/extensions/herdr-omp-agent-state.ts`（由 `herdr integration install omp`
  管理，不进 Home Manager）。
- 变更内容：`~/.config/herdr/config.toml` 新增
  `[ui.toast] delivery = "herdr"`，后台 Agent 完成或需要输入时弹出应用内 toast；并通过 Herdr 官方
  `omp`
  集成扩展让 Herdr 识别 OMP 会话状态。提示音沿用默认开启。本机无 dunst/mako 等系统通知守护进程，故未使用
  `system`/`terminal` 投递模式。
- 验证方式：`nixfmt --check` 与 apollo Home
  Manager 配置求值确认新 config.toml 内容；对运行中的 server 执行 `herdr server reload-config` 后
  `herdr notification show` 返回 `shown: true`；`herdr integration status` 显示
  `omp: current (v3)`，`herdr pane list` 中当前 Pane 显示 `"agent":"omp"`。未执行 `just local`
  或系统切换。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)。

## 2026-08-14

### 安装 bb Agent IDE（用户级 npm）

- 影响范围：当前用户环境的可用 Agent 工具集；不涉及 Nix 配置、Home Manager 或系统服务变更。
- 配置入口：无 Nix 变更；文档为 `documents/bb.md`，npm 全局前缀与 PATH 沿用
  `home/base/core/npm.nix`、`home/base/core/shells/default.nix`。
- 变更内容：通过 `npm install -g bb-app@latest` 安装 bb（`get-bb/bb`，agentic IDE，提供 `bb`
  CLI、`bb-app` launcher、Web UI 与 HTTP API）；沿用 OpenCode /
  Pi 的用户级安装约定，不通过 Nix 固定版本，数据目录为 `~/.bb/`。
- 验证方式：`bb --version` 返回 `0.37.0`；以 `BB_TELEMETRY=false` 启动 `bb-app`
  后确认 38886 端口的应用与 `/api/health` 均返回200；`bb status`
  成功连接运行中的 server；验证后已停止冒烟实例。
- 关联文档：[bb Agent IDE](./bb.md)。

## 2026-08-13

### Herdr Pane 跳过 Zellij 自动启动

- 影响范围：全部加载共享 TUI Home Manager 配置的 Linux 与 macOS 主机。
- 配置入口：`home/base/tui/zellij/default.nix`。
- 变更内容：Nushell 自动启动 Zellij 的条件增加
  `(not ("HERDR_ENV" in $env))`，Herdr 交互式 Pane（Herdr 注入
  `HERDR_ENV=1`）不再嵌套 Zellij，直接进入 Nushell；普通终端行为不变。原因：嵌套复用器会使 Herdr 的 Agent 检测失效，Pane 前台进程显示为 Zellij，Agents 面板始终为空。只影响新启动的 Shell，已运行 Pane 需退出 Zellij 或重建。
- 验证方式：检查 Herdr Pane 进程环境存在 `HERDR_ENV=1`；执行 Home Manager 配置求值与仓库 eval
  tests；未执行 `just local` 或系统切换。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)。

## 2026-08-12

### 修复 Herdr Pane 的错误 Shell 提示符显示

- 影响范围：全部加载共享 TUI Home Manager 配置的 Linux 与 macOS 主机中新建的 Herdr 交互式 Pane。
- 配置入口：`home/base/tui/dev-tools.nix`。
- 变更内容：通过 `~/.config/herdr/config.toml` 将 Herdr 的默认交互式 Shell 固定为 Home
  Manager 管理的登录 Nushell，避免 Herdr 回退到 `$SHELL` 后进入 Bash 初始化链并显示字面量
  `\[\]`；不改终端字体。
- 验证方式：对比默认 Bash Pane 与仅切换 Nushell 的隔离 Herdr `0.7.1` 会话，确认 `shopt` 错误和
  `\[\]` 同时消失，且边框、中文与 Nerd Font 字符探针正常；执行 Home
  Manager 配置求值、构建与仓库 eval tests；未执行 `just local` 或系统切换。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)。

### 安装 Herdr Agent 终端运行时

- 影响范围：全部加载共享 TUI Home Manager 配置的 Linux 与 macOS 主机。
- 配置入口：`home/base/tui/dev-tools.nix`。
- 变更内容：通过主 `nixpkgs` 的 `pkgs.herdr`
  安装 Herdr；保留现有 Zellij 自动启动链路，Herdr 按需手动启动，不新增系统服务。
- 验证方式：执行 Herdr 包版本求值、Home Manager 包集合求值、Herdr 包构建与仓库 eval tests；未执行
  `just local` 或系统切换。
- 关联文档：[Herdr Agent 终端运行时](./herdr.md)。

## 2026-07-25

### 将 Type4Me 切换为已发布的远程 flake

- 影响范围：Apollo 及使用 Linux GUI 基础模块的 Type4Me 用户服务。
- 配置入口：`flake.nix`、`flake.lock`、`documents/linux-voice-input.md`。
- 变更内容：将 Type4Me 输入从本机绝对路径切换为 GitHub flake，并将锁文件固定到
  `3e367432036bbbbb035dbaa6229ecb3ce94ee2d8`，使 CUDA 识别构建可由配置仓库独立复现。
- 验证方式：Type4Me 提交已推送，`nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.systemd.user.services.type4me-linux.Service.ExecStart --json`
  成功解析新的 Nix store 服务路径；未执行 `just local` 全系统切换。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

## 2026-07-24

### 将 Noctalia 启动器切换为 Alt + Space

- 影响范围：全部使用通用 Niri 配置的 Linux GUI 主机，以及应用自身的 `Alt + Space` 快捷键。
- 配置入口：`home/linux/gui/niri/conf/keybindings.kdl`。
- 变更内容：将 Noctalia 应用启动器的全局入口从 `Mod + Space` 改为 `Alt + Space`；保留 `Mod + D` 和
  `XF86Search` 作为备用入口。
- 验证方式：使用 Niri `26.04` 执行 `niri validate`，确认当前 `/home/vitus/.config/niri/config.kdl`
  配置有效；未执行系统切换。
- 关联文档：[Niri 工作区与窗口分配](./niri-workspaces.md)。

## 2026-07-19

### 自动恢复 XWayland 重启后丢失的 Fcitx5 XIM

- 影响范围：全部 Linux GUI 主机的 Fcitx5 XIM 注册，以及 WeChat `4.1.1.4`
  在 Niri/XWayland 下的 Rime 候选框。
- 配置入口：`home/linux/gui/base/fcitx5/default.nix`。
- 变更内容：保留首次启动前的 XWayland 探测，并增加
  `fcitx5-xim-recovery.timer`；图形会话中每 10 秒检查一次
  `XIM_SERVERS`，仅在属性缺失时重启 Fcitx5。该机制修复显示器断连导致 `xwayland-satellite`
  退出后，Fcitx5 不会随 satellite 重建而重新注册 XIM 的问题。
- 验证方式：本次启动日志确认 Fcitx5 首次注册成功；显示器断连时 satellite 以状态 `101`
  退出，Fcitx5 同时记录 XCB 断连。故障注入终止 satellite 后确认 `XIM_SERVERS`
  消失；运行恢复脚本后 Fcitx5 PID 更新、satellite 重建，`XIM_SERVERS(ATOM) = @server=fcitx`
  恢复。Apollo `system.build.toplevel` 构建及恢复脚本 ShellCheck 通过；新定时器尚未执行系统部署。
- 关联文档：[Fcitx5 与 Rime 小鹤双拼](./fcitx5-rime-input-method.md)、[Linux 微信与 QQ](./linux-im-apps.md)。

## 2026-07-18

### 修复 Type4Me systemd 单例所有权

- 影响范围：Apollo 及使用 Linux GUI 基础模块的 Type4Me 常驻服务。
- 配置入口：`home/linux/gui/base/voice-input.nix`。
- 变更内容：将 unit 的启动命令从通用 `gui --background` 切换为专用 `service` 入口；该入口使用 Gio
  service 模式，已有 GUI 占用应用总线名称时会失败并由 systemd 重试，不再作为远程客户端成功退出后脱离监管。
- 验证方式：Type4Me
  460 项测试和 flake 构建通过；已有单例冲突返回失败码 1，隔离 D-Bus/Xvfb 会话中的 service 持续运行；`nixfmt --check`、`niri validate`
  和 `nix flake check --no-build` 通过。未执行 `just local` 或 `nixos-rebuild switch`。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### 消除 Niri 按需 XWayland 导致的 Fcitx5 启动竞态

- 影响范围：全部 Linux GUI 主机的 Fcitx5 XIM 注册，以及 WeChat `4.1.1.4`
  在 Niri/XWayland 下的 Rime 候选框。
- 配置入口：`home/linux/gui/base/fcitx5/default.nix`。
- 变更内容：为 `fcitx5-daemon.service` 增加 `ExecStartPre=xprop -root`；先触发并确认 Niri `26.04`
  的按需 XWayland 已经可连接，再启动 Fcitx5 注册
  `XIM_SERVERS`，消除仅禁用重复 autostart 后仍存在的登录启动竞态。WeChat 继续隐藏 `WAYLAND_DISPLAY`
  并强制使用 XWayland/XIM。
- 验证方式：现场复现 `XIM_SERVERS` 不存在且微信同时出现 `wayland_v2` 与 `fcitx4`
  输入上下文；重启 Fcitx5 和 WeChat 后确认 `XIM_SERVERS(ATOM) = @server=fcitx`，微信只进入
  `Group [x11::0]` 且前端为 `fcitx4`。求值确认 Apollo 和 Athena 的服务均包含 `xprop -root`
  启动前置命令，两台主机的 `system.build.toplevel` 均构建成功。仓库配置尚未执行 `just local` 或
  `nixos-rebuild switch` 部署。
- 关联文档：[Fcitx5 与 Rime 小鹤双拼](./fcitx5-rime-input-method.md)、[Linux 微信与 QQ](./linux-im-apps.md)。

## 2026-07-15

### 完全移除 Voxtype 语音输入

- 影响范围：Apollo 及使用 Linux GUI 基础模块的 Niri 桌面；Type4Me 成为唯一语音输入方案。
- 配置入口：`home/linux/gui/base/voice-input.nix`、`home/linux/gui/niri/conf/keybindings.kdl`。
- 变更内容：删除 `pkgs.voxtype-vulkan` 用户包、`~/.config/voxtype/config.toml`、 `voxtype.service`
  及其 Vulkan/OpenCC 配置；保留 Type4Me 服务、模型管理、Wayland 文本注入工具和
  `Scroll Lock`/`Shift + Scroll Lock` D-Bus 快捷键。当前会话中的旧 Voxtype
  unit 已停止并禁用，用户模型数据未自动删除。
- 验证方式：Apollo Home Manager 求值确认服务集合不含 `voxtype`、用户包集合不含 Voxtype，且
  `type4me-linux` 服务仍存在；`niri validate`、`nixfmt --check` 和 `nix flake check --no-build`
  通过。未执行 `just local` 或 `nixos-rebuild switch`。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)、[应用版本审计](./application-version-audit.md)。

## 2026-07-14

### 补齐 apollo 双系统 RTC 首次校准步骤

- 影响范围：`apollo` 在 NixOS 与 Windows 之间切换时的硬件时钟一致性。
- 配置入口：`hosts/olympians-apollo/default.nix`；当前继续使用
  `time.hardwareClockInLocalTime = true`，本次不改变系统配置。
- 变更内容：确认运行中的 NixOS 已按本地时间解释 RTC，但硬件时钟仍保留 UTC 值，导致 RTC 与
  `Asia/Shanghai` 本地时间相差 8 小时；补充首次启用后的 `hwclock --systohc --localtime --noadjfile`
  校准、状态检查和 Windows 时间同步步骤。`--noadjfile` 避免 `hwclock` 尝试改写由 Nix
  store 提供的只读 `/etc/adjtime`。
- 验证方式：`timedatectl status` 确认系统时钟已同步、NTP 服务为 active、`RTC in local TZ` 为
  `yes`，同时观测到校准前 `RTC time` 比 `Local time` 少 8 小时；util-linux `2.42` 的
  `hwclock --help` 和手册确认 `--noadjfile` 会跳过
  `/etc/adjtime`。实际 RTC 写入由用户在本机终端执行。
- 关联文档：[rEFInd 双系统启动](./refind-boot.md#双系统时间校准)。

## 2026-07-13

### 将 Niri 语音输入快捷键切换到 Type4Me

- 影响范围：Apollo 及使用 Linux GUI 基础模块的 Niri 桌面；`Scroll Lock`
  切换 Type4Me 录音，`Shift + Scroll Lock` 取消录音，Voxtype 保留为未绑定快捷键的后备服务。
- 配置入口：`flake.nix`、`flake.lock`、`home/linux/gui/base/voice-input.nix`、
  `home/linux/gui/niri/conf/keybindings.kdl`。
- 变更内容：增加本地 `path:/home/vitus/type4me-linux` flake 输入并锁定，安装 Type4Me
  `0.1.0`，增加随 Wayland 会话启动的 `type4me-linux.service`；Niri 26.04 通过
  `io.github.vitus.Type4Me.Controller` D-Bus 接口调用 `Toggle` 和 `Cancel`。当前 GNOME
  Portal 后端的 GlobalShortcuts v1 在 `BindShortcuts` 返回响应码 `2`，因此保留 compositor 原生绑定。
- 验证方式：`niri validate` 通过；Apollo Home Manager 服务和包集合求值通过；Type4Me
  flake 包构建成功；当前会话服务为 `active`，D-Bus 五个控制方法均已导出，真实 `Toggle` 和 `Cancel`
  调用成功。未执行 `just local` 或 `nixos-rebuild switch`。
- 关联文档：[Linux 语音输入](./linux-voice-input.md)。

### 将 Noctalia 壁纸源切换到个人仓库

- 影响范围：全部 Linux GUI 主机的 Noctalia Shell `4.4.3`；壁纸选择器改为递归读取
  `Vitus213/wallpapers` 仓库 `jpg/` 目录中的 8 张 JPG，自动换壁纸保持关闭。
- 配置入口：`flake.nix`、`flake.lock`、`home/linux/gui/base/noctalia/default.nix`、
  `home/linux/gui/base/noctalia/config/settings.json`。
- 变更内容：将壁纸 input 从 `ryan4yin/wallpapers` 切换为 `github:Vitus213/wallpapers`，锁定提交
  `e1c407b445c9a3c6d2606302b5d375cae9a51c88`；Home Manager 只把 input 的 `jpg/` 子目录链接到
  `~/Pictures/Wallpapers`，Noctalia 继续读取该稳定路径并保留 `automationEnabled = false`。
- 验证方式：`nix flake check --no-build` 和 `just test` 均通过；Apollo Home Manager 求值确认
  `wallpapers` input 存在，链接源为锁定仓库的 `jpg/` 子目录，并精确包含 8 张预期 JPG。未执行
  `just local` 或 `nixos-rebuild switch`。
- 关联文档：[Linux 桌面基础配置](../home/linux/gui/base/README.md#壁纸来源)。

## 2026-07-12

### 更新 Orca 至 1.4.137

- 影响范围：全部 Linux GUI 主机的 StablyAI Orca，由 `1.4.135` 更新至官方最新稳定版 `1.4.137`。
- 配置入口：`overlays/stably-orca/default.nix`。
- 变更内容：更新官方 Linux AppImage URL 和固定哈希，保留 Orca 进程级 Nushell 默认值、`/etc/agenix`
  目录级只读映射和 XDG 自启动。上游新增全平台终端右键粘贴，并修复 Linux daemon 在 PTY 启动前的 Unix
  shell fallback、后台恢复后的陈旧终端窗格、Claude 问题等待状态等问题。
- 验证方式：构建 `apollo.pkgs.stably-orca`；求值确认版本为 `1.4.137`；确认生成的桌面文件包含
  `Exec=orca %U` 和 `X-AppImage-Version=1.4.137`，启动器设置 Nushell
  `0.113.1`，Bubblewrap 启动器保留 `--ro-bind-try /etc/agenix /etc/agenix`。未执行 `just local` 或
  `nixos-rebuild switch`。
- 关联文档：[Orca 桌面应用](./orca.md)、[应用版本审计](./application-version-audit.md)。

### 恢复 Esc 与 Caps Lock 原生键位

- 影响范围：全部 NixOS 桌面主机和 macOS Artemis；`Esc` 恢复 Escape，`Caps Lock`
  恢复系统大写锁定，不再交换两个键，也不再提供点按 Escape、长按 Control 的复合行为。
- 配置入口：`modules/nixos/desktop/peripherals.nix`、`modules/darwin/system.nix`。
- 变更内容：移除 Linux 上仅用于 Esc/Caps Lock 映射的 `keyd 2.6.0` 服务配置；移除 macOS 的 nix-darwin
  `system.keyboard` 映射。Fcitx5/Rime 继续禁止 Caps Lock 参与中西文切换，不改变其系统键位。
- 验证方式：求值确认 Apollo、Athena 和 Generic 的 `services.keyd.enable` 均为
  `false`；确认 Artemis 的 `system.keyboard.enableKeyMapping` 为 `false` 且 `userKeyMapping`
  为空。未执行 `just local`、`nixos-rebuild switch` 或
  `darwin-rebuild switch`，实体键行为需部署后实测。
- 关联文档：[Esc 与 Caps Lock 原生键位](./keyboard-layout.md)、[Fcitx5 与 Rime 小鹤双拼](./fcitx5-rime-input-method.md)。

### 登录图形会话后自动启动 Orca

- 影响范围：全部 Linux GUI 主机的 StablyAI Orca
  `1.4.135`；用户进入 Niri 图形会话后自动打开 Orca，不在缺少 Wayland、D-Bus 和 portal 环境的系统引导阶段启动。
- 配置入口：`home/linux/gui/base/xdg/autostart.nix`。
- 变更内容：将 `pkgs.stably-orca` 提供的 `orca.desktop` 加入 Home Manager XDG
  autostart 列表；继续沿用 `app-id="orca"` 的 Niri 窗口规则，启动后进入 `5code` 工作区并最大化。
- 验证方式：求值确认 Apollo 和 Athena 的 XDG autostart 列表均包含 Orca `1.4.135`
  桌面文件；构建Apollo Home Manager generation，确认生成的 `~/.config/autostart/orca.desktop` 包含
  `Exec=orca %U`、`Terminal=false` 和 `X-AppImage-Version=1.4.135`。未执行 `just local` 或
  `nixos-rebuild switch`。
- 关联文档：[Orca 桌面应用](./orca.md)。

### 将桌面壁纸切换为本机 WLOP 作品

- 影响范围：全部 Linux GUI 主机的 Noctalia 壁纸目录；每台主机需要单独准备不受 Git 管理的本机图片。
- 配置入口：`home/linux/gui/base/noctalia/config/settings.json`、
  `home/linux/gui/base/noctalia/default.nix`、`flake.nix`、`flake.lock`。
- 变更内容：从 WLOP 官方 ArtStation 筛选 8 张横屏展示图，仅保存到本机
  `~/Pictures/WLOP`；Noctalia 改为递归扫描该目录。移除 `wallpapers` flake input 和 Home
  Manager 的只读壁纸目录映射；公开仓库 [Vitus213/wallpapers](https://github.com/Vitus213/wallpapers)
  删除旧图片，改为只记录 WLOP 官方作品页、本机文件名和分辨率，并忽略所有图片/视频文件，避免公开再分发未授权原图。
- 验证方式：确认 8 张本机文件均为可识别 JPEG，分辨率覆盖 `1920x753` 至 `1920x1126`；确认
  `noctalia-shell.service` 为 `active`，通过 IPC 将所有显示器切换到 `dome.jpg`，运行时缓存记录
  `DP-1` 已使用该文件；执行 `nix eval .#evalTests --show-trace --print-build-logs --verbose` 返回
  `true`， `nixfmt --check` 通过。未执行 `just local`。
- 关联文档：[Linux 桌面基础配置](../home/linux/gui/base/README.md)、
  [WLOP 壁纸来源清单](https://github.com/Vitus213/wallpapers)。

## 2026-07-11

### 更新 Orca 至 1.4.135

- 影响范围：Linux 图形桌面的 StablyAI Orca，由 `1.4.134` 更新至官方最新的 `1.4.135`。
- 配置入口：`overlays/stably-orca/default.nix`。
- 变更内容：更新官方 Linux AppImage URL 和固定哈希；保留 Orca 进程级 Nushell 默认值及 `/etc/agenix`
  目录级只读映射。上游版本包含 Linux 文件监视循环、终端冻结和性能、Codex 重复 TOML project
  key、SSH 与远程连接可靠性等修复。
- 验证方式：构建 `apollo.pkgs.stably-orca`；求值确认版本为 `1.4.135` 且 Apollo Home
  Manager 用户包列表仍包含 Orca；确认生成的启动器设置 Nushell `0.113.1`，Bubblewrap 启动器保留
  `--ro-bind-try /etc/agenix /etc/agenix`，并执行包装器指定的 `nu -l` 确认版本。未执行 `just local`
  或 `nixos-rebuild switch`。
- 关联文档：[Orca 桌面应用](./orca.md)、[应用版本审计](./application-version-audit.md)。

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
