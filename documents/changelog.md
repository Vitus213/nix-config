# 变更记录

本文件作为仓库配置变更的主线索引，按时间倒序记录。具体背景、当前行为、使用方式、验证和回滚步骤应写入关联专题文档。

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
