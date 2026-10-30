# Herdr Agent 终端运行时

本文记录当前 Herdr 的安装来源、与 Zellij 的关系，以及从手机通过 SSH 接入持久会话的方式。

## 当前配置

Herdr 二进制改为官方安装（`curl -fsSL https://herdr.dev/install.sh | sh`，装至
`~/.local/bin`，更新走 `herdr update` 自管理）。仓库只通过 `home/base/tui/dev-tools.nix` 的
`home.activation.herdrConfig` 生成 `~/.config/herdr/config.toml`。

当前运行版本与 `apollo` 配置求值结果：

| 组件        | 版本      | 来源                                       |
| ----------- | --------- | ------------------------------------------ |
| Herdr       | `0.9.5`   | `~/.local/bin` 官方安装（自管理）          |
| herdr-radar | `1.4.9`   | `herdr plugin install`（用户级，自管理）   |
| auto-title  | `0.14.0`  | `herdr plugin install`（用户级，Go 构建）  |
| Nushell     | `0.116.1` | Home Manager 的 `programs.nushell.package` |

Linux 与 macOS 的共享 TUI 配置都会生成同一份 Herdr 配置文件。

`athena` 于 2026-10-28 对齐到同一套插件与集成：`herdr` `0.9.5`、herdr-radar `1.4.9` （钉
`3e72fe2`）、auto-title
`0.14.0`（同样打了「不命名 tab」补丁）、`herdr integration install omp`；未装 `claude`
集成（athena 无 claude 二进制）。athena 上 `git clone https://github.com/…` 会被 OpenClash
fake-ip 链路重置，安装时改用 GitHub 反代做本地镜像 + `url.<base>.insteadOf`
重写，完整步骤与验证命令见本仓库 `servers/athena.md`（all_server 仓库）。

`config.toml` 是**可写的普通文件**，不是 Home
Manager 的只读 symlink：herdr-radar 插件和 Herdr 自身（例如侧边栏排序切换）都会改写它。每次 Home
Manager 激活时按以下规则重新生成：

1. 写入 Nix 声明的基础内容（下方代码块）；
2. 从旧文件中取出 `# >>> herdr-radar {tab-bar,theme,sidebar} block` 到对应 `# <<<`
   的托管块，按 tab-bar、theme、sidebar 顺序追加到末尾；
3. 其余手工改动（含 Herdr 设置界面写入的键）会被基础内容覆盖。要长期保留，就写进 `dev-tools.nix`。

基础内容中 `[ui]` 必须是最后一个表：radar 的 tab-bar 块是 `[ui]` 下的裸键，追加到末尾时才会落在
`[ui]` 里；radar 也要求文件中显式存在 `[ui]` 表，否则拒绝写入。

```toml
onboarding = false

[terminal]
default_shell = "/etc/profiles/per-user/vitus/bin/nu"
shell_mode = "login"

[theme]
name = "catppuccin"

[[keys.command]]
key = "prefix+a"
type = "plugin_action"
command = "hhdebb.herdr-radar.view-flip"

[[keys.command]]
key = "prefix+comma"
type = "plugin_action"
command = "hhdebb.herdr-radar.settings"

[ui.toast]
delivery = "system"
delay_seconds = 1

[ui]
prompt_new_tab_name = false
```

Herdr 的 `default_shell` 只接受可执行文件名或路径，不接受带参数的命令行。这里刻意使用
`${config.home.profileDirectory}/bin/nu`（两台主机均解析为
`/etc/profiles/per-user/vitus/bin/nu`）这类跨 rebuild 稳定的 profile 路径，而不是 Nushell 的 store 绝对路径：长驻的 herdr
server 只在启动或 `reload-config`
时读取配置，store 路径会在 Nushell 升级后指向已被替换的旧二进制。`shell_mode = "login"`
负责以登录 Shell 方式启动 Nushell；已有 Pane 会保留当前进程，直到手动替换 Shell 或重建 Pane。

## 启动与持久会话

在项目目录中启动：

```bash
herdr
```

Herdr 会连接默认后台会话；Linux 上该会话由 systemd 用户服务提供（见下节），服务未运行时客户端才会自行拉起 server。分离客户端后，Herdr 后台服务器、Pane 和 Agent 进程继续运行：

```text
Ctrl+B Q
```

之后再次运行 `herdr` 即可重新连接。需要停止默认会话及其中进程时运行：

```bash
herdr server stop
```

## 后台 server：systemd 用户服务（Linux）

Linux 上 herdr server 由 `home/base/tui/dev-tools.nix` 的 `systemd.user.services.herdr` 托管：

- `ExecStart = ~/.local/bin/herdr server`（官方文档建议服务式部署使用该子命令），随
  `graphical-session.target` 启动，从而继承 niri 导入的 `WAYLAND_DISPLAY`、`PATH`
  等环境，pane 内的剪贴板、浏览器登录等照常工作。
- **原因**：此前 server 由第一次运行 `herdr` 的终端拉起，落在该终端的 cgroup 中（曾在
  `app-Alacritty@autostart.service`
  下）。一旦那个 unit 被停止，systemd 会连带杀掉 server 和所有 agent。独立服务后，终端窗口只是客户端。
- `ExecCondition`：已有 server 在运行（`herdr status server` 输出
  `status: running`）时跳过启动，避免抢 socket。
- `Restart = always`：`herdr server stop` 后 3 秒自动拉起，并按快照恢复布局与 agent 会话。真正停止用
  `systemctl --user stop herdr`。
- `X-RestartIfChanged = false`：重启服务会结束所有 pane，因此 Home Manager 切换时不自动重启。

### 首次迁移

部署后旧 server 仍挂在原终端下，服务会被 `ExecCondition` 跳过。等手头 agent 告一段落后：

```bash
herdr server stop               # 结束旧 server（会结束所有 pane 进程）
systemctl --user start herdr    # 由 systemd 启动新 server，恢复布局
herdr                           # 重新连接
systemctl --user status herdr   # 应为 active (running)
```

在集成安装之前启动的 Claude 会话没有登记会话 ID，迁移后不会自动恢复，需要在对应目录手动
`claude --resume`。

### 升级

`herdr update` 只替换二进制，旧 server 继续运行；需要新 server 时执行
`systemctl --user restart herdr`（结束所有 pane，按快照恢复）。不要使用
`herdr update --handoff`：它会换掉 server 进程，和 systemd 的主进程跟踪冲突。

## 与 Zellij 的关系

普通终端（Ghostty、Foot 等）中的 Nushell 仍会自动进入 Zellij；Herdr Pane 中则跳过该自动启动：

- `home/base/tui/zellij/default.nix` 的自动启动条件包含 `(not ("HERDR_ENV" in $env))`。
- Herdr 会给每个交互式 Pane 注入 `HERDR_ENV=1`，因此 Herdr
  Pane 里直接进入 Nushell，不会嵌套 Zellij。
- 原因是嵌套复用器会让 Herdr 的 Agent 检测失效：Herdr 只识别 Pane 的前台进程，若前台进程是 Zellij/tmux，背后的 Agent（Claude
  Code、Codex 等）不会被识别，Agents 面板会一直为空。该条件只影响新启动的 Shell；已运行的 Pane 需退出 Zellij 或重建 Pane 后生效。

如果在 Zellij 的 Pane 中手动运行
`herdr`，仍会形成嵌套终端复用器，双方都会处理分屏、复制和前缀键，且 Herdr 无法检测其中运行的 Agent。临时试用可以这样做，长期使用时应让一个工具负责会话管理：以 Herdr 为主时，先退出当前 Zellij 会话回到外层 Shell，再运行
`herdr`。

## 剪贴板图片粘贴（kitty 外层终端）

OMP 在 SSH 会话里粘贴图片走 kitty 的 OSC 5522 剪贴板读取协议；foot 只有 OSC
52 文本剪贴板，传不了图片。Herdr 二进制内置同一协议的处理逻辑，kitty 作外层终端即可打通
`OMP → Herdr pane → Herdr client → kitty` 链路：

1. `Mod+Ctrl+Return` 打开 kitty（kitty 里 Nushell 不会自动进 Zellij）。
2. 运行 `herdr`，在 pane 里 `ssh` 到目标主机跑 OMP；也可以在 kitty 里直接 `ssh` 跑 OMP。
3. 本机复制截图，在 OMP 输入框按粘贴：OMP 发出 OSC 5522 读取请求，kitty 授权后回传图片。

读剪贴板时 kitty 默认弹授权确认，保持 ask，不自动放行。kitty 默认
`TERM=xterm-kitty`，SSH 目标机缺该 terminfo 的处理见 [终端说明](../home/base/gui/terminal/README.md)
的「`xterm-kitty` 远程主机问题」。

## Shell 与字体排障

Herdr 不自行选择字体，外层终端负责最终字形渲染。当前 Ghostty `1.3.1` 与 Foot `1.27.0` 都使用
`Maple Mono NF CN`；边框字符、中文和 Nerd Font 字符探针均可正常显示：

```text
┌─┬─┐ │ 中文  │ └─┴─┘
```

本次故障复现出的实际输出是：

```text
bash: shopt: progcomp: invalid shell option name
\[\]nix-config\[\] ...
```

这些 `\[\]` 来自错误进入 Bash 初始化和提示符链路，并非字体缺字。Herdr 在未配置
`terminal.default_shell` 时会读取
`$SHELL`；本仓库的 Ghostty、Foot、Kitty 与 Alacritty 则都显式启动 Nushell，因此两条启动链此前不一致。

部署配置后先让运行中的 server 重新读取配置：

```bash
herdr server reload-config
```

该设置只影响新建的交互式 Pane。当前 Pane 位于空闲 Shell 提示符时，可直接替换为登录 Nushell：

```bash
exec nu --login
```

也可以关闭并重建受影响的 Pane。只有确认 Pane 内没有需要保留的进程时，才停止整个默认会话：

```bash
herdr server stop
herdr
```

停止 server 会结束其中的 Pane 进程。

## 排查记录：Pane 启动 Nushell 报 str lowercase 解析错误（2026-10-17）

现象：artemis 上 Herdr 新建 Pane 时 Nushell 打印启动报错，之后仍进入提示符：

```text
Error: nu::parser::extra_positional
× Extra positional argument.
  ╭─[/nix/store/…-nushell-fzf-integration.nu:313:45]
  | where {|it| ($it | str lowercase | str starts-with 'host') … }
  help: Usage: str
```

根因：Home Manager（master）生成的 fzf 集成脚本使用了 Nushell `0.114.0` 才引入的 `str lowercase`
无参数管道写法（脚本内自带 NOTE 说明），而报错 Pane 的 Nushell 是 `0.113.1`——herdr
server 自 10-06 起长驻运行，内存中仍持有旧配置的
`default_shell = /nix/store/…-nushell-0.113.1/bin/nu`（store 绝对路径）。10-07 的 switch 把系统 Nushell 升到
`0.115.1` 并部署了新 fzf 集成脚本，旧二进制解析新 `config.nu`
即报此错。普通终端（Ghostty 等经 PATH 启动 nu）不受影响。

修复：

1. `herdr server reload-config`：server 重读配置（已指向 nushell-0.115.1），只影响新建 Pane；
2. `terminal.default_shell` 改为 `/etc/profiles/per-user/vitus/bin/nu`
   稳定 profile 路径，即使 server 未来忘记 reload，该路径也在每次 spawn 时解析到当前 generation 的 nu。

验证：`nu --config ~/.config/nushell/config.nu -c 'print ok'`（0.115.1）解析通过；用 0.113.1 二进制加载同一配置可复现原报错。apollo 侧的同源风险已随主
`nixpkgs` 更新（Nushell `0.116.1`）解除，见
[Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md) 的版本约束说明。

## 通知与 Agent 集成（OMP）

Herdr 可以在 Agent 完成或需要输入时弹出通知。当前配置为：

- `[ui.toast] delivery = "system"`：以桌面通知弹出。Linux 上由 Herdr
  **client**（运行在 foot 里的那个进程）调用
  `notify-send --app-name Herdr`，由 noctalia-shell 的通知服务显示；macOS 上用
  `terminal-notifier`，缺失时回退 `osascript`。
- 抑制规则：Herdr 不为当前活动 tab 弹通知，但会读取外层终端的焦点事件。foot 在前台时只有其他 tab 的 Agent 会弹；foot 切到后台后，当前 tab 的 Agent 完成也会弹。
- 弹出前等待 `delay_seconds = 1` 秒，期间状态变了就不弹。
- `[ui.sound]` 未显式配置，沿用默认 `enabled = true`，后台 Workspace 的 Agent 状态变化同时有提示音。

几种 `delivery` 在本机的取舍（依据 Herdr `0.9.5` 源码
`src/terminal_notify.rs`、`src/platform/linux.rs`）：

| 值         | 行为                                                       | foot 下                  |
| ---------- | ---------------------------------------------------------- | ------------------------ |
| `system`   | client 调 `notify-send`                                    | 可用（当前）             |
| `terminal` | 向外层终端写 OSC 9/99，只识别 Ghostty/iTerm2/Kitty/WezTerm | 不弹：`TERM=foot` 被跳过 |
| `herdr`    | Herdr 界面内 toast，终端不在前台时看不到                   | 可用，但看不到           |
| `off`      | 关闭弹窗                                                   | —                        |

`delivery` 只能选一个，选 `system` 后 Herdr 界面内不再有 toast。排查时先单独测试通知链路：

```bash
notify-send --app-name Herdr -- "测试" "桌面应弹出这条"
```

修改后对运行中的 server 执行 `herdr server reload-config`，不会结束 Pane。

OMP 的状态上报通过 Herdr 官方集成安装：

```bash
herdr integration install omp
```

该命令在 `~/.omp/agent/extensions/` 写入 `herdr-omp-agent-state.ts`。这是用户级文件，不由 Home
Manager 管理；升级或检查状态用 `herdr integration status`，移除用
`herdr integration uninstall omp`。扩展在 OMP 启动时读取 Herdr 注入的
`HERDR_ENV`、`HERDR_SOCKET_PATH`、`HERDR_PANE_ID`，通过本地 socket 上报 Agent 状态；在 Herdr
Pane 之外运行的 OMP 不受影响。已经在运行的 OMP 会话需要重启才能加载该扩展。

验证：

```bash
herdr integration status          # omp 行应显示 current (vN)
herdr pane list                   # 目标 Pane 应显示 "agent":"omp"
herdr notification show "测试"    # 前台 Pane 繁忙时返回 reason: busy
```

## 侧边栏 Agent 状态：herdr-radar 插件

Herdr 内置的 Agents 面板只用小圆点颜色区分状态，`done` 被看过后很快回落为
`idle`，问你问题的 agent 和闲置很久的 agent 看起来差不多。这里改用社区插件
[hhdebb/herdr-radar](https://github.com/hhdebb/herdr-radar) 重绘侧边栏：

| 状态    | 标题颜色 | 标题前标记                |
| ------- | -------- | ------------------------- |
| working | 厂商色   | 盲文转轮动画              |
| blocked | 红       | 闪烁的 `?`，等你确认/选择 |
| done    | 绿       | `✓`，保持到你聚焦该 pane  |
| idle    | 渐变     | 圆环；超过 2 小时整行变暗 |

此外同一项目的 agent 归在一个表头下，按活跃度排序，Spaces 列使用相同配色。

Claude Code 的状态仍由 Herdr 读屏判断（`herdr integration install claude`
只提供会话恢复，不上报状态）；radar 只负责把状态显示得更醒目、更持久。

### 安装（一次性，用户级）

插件不由 Nix 管理，与 Herdr 二进制一样自管理。需要 Node 18+（`home/base/tui/editors/packages.nix`
已提供 `nodejs_22`）。先部署本仓库配置，让 `config.toml` 变成可写文件，再安装：

```bash
just local                                   # 或 darwin 对应命令
herdr plugin install hhdebb/herdr-radar      # 构建步骤写入托管块、安装图标字体
herdr plugin action invoke hhdebb.herdr-radar.configure    # 托管块未写入时补写并重载
herdr plugin action invoke hhdebb.herdr-radar.state-start  # 启动状态守护进程
```

不要为此执行 `herdr server stop`，它会结束所有 pane 中的进程。

### 主题与字体

- 读不到桌面明暗（Linux 上没有 `gsettings`）时，radar 按 `[theme] name`
  选配色，未设置会回退浅色配色、在深色终端里看不清。因此基础配置显式写
  `name = "catppuccin"`（深色）。
- 图标字体 `Herdr Agent Icons Max` 装到 `~/.local/share/fonts`，占用 `U+E1A0`
  起的两段私有区码位。`Maple Mono NF CN`
  不覆盖这两段，foot/alacritty 会通过 fontconfig 自动回退，Linux 上不需要改终端配置。foot 以 server 模式常驻，只在启动时读取字体列表；首次装字体后需
  `systemctl --user restart foot.service`（会关闭所有 foot 窗口，herdr
  server 不受影响）再重开窗口，否则图标显示为方块。macOS 的 Ghostty 配置是 Home
  Manager 只读文件，插件写不进码位映射；如果 logo 显示成方块，就在
  `home/base/gui/terminal/terminals.nix` 的 ghostty settings 中加 `font-codepoint-map`。
- 上游 README 标注 Linux 尚未实测；异常时先看
  `herdr plugin log list --plugin hhdebb.herdr-radar --limit 20`。

### 快捷键与设置

- `prefix+a`（默认 `ctrl+b a`）：Agents 排序在 active（分组）与 recent（扁平）之间切换。
- `prefix+,`：打开 radar 设置弹窗（`done_hold`、`activity_stale_minutes` 等）。设置保存在
  `$(herdr plugin config-dir hhdebb.herdr-radar)/config.toml`，不由 Nix 管理。

### 更新与移除

```bash
herdr plugin update hhdebb.herdr-radar
herdr plugin action invoke hhdebb.herdr-radar.state-stop
herdr plugin action invoke hhdebb.herdr-radar.state-start
```

移除时先清托管块，再卸载：

```bash
herdr plugin action invoke hhdebb.herdr-radar.unconfigure
herdr plugin action invoke hhdebb.herdr-radar.uninstall-font
herdr plugin uninstall hhdebb.herdr-radar
```

不用插件时，基础配置中的两个 `keys.command` 只是失效按键，可从 `dev-tools.nix` 删掉。

## Pane 自动命名：auto-title 插件

[kryptamine/herdr-auto-title](https://github.com/kryptamine/herdr-auto-title)
按 pane 里的工作命名 pane（goto 面板、侧边栏可见）并上报工作区 topic：agent 用会话标题，普通 Shell 用目录与分支。手动改过名的 pane 不再被接管，清空名字即交还。

**本机补丁：不命名 tab。** tab 栏只显示 Herdr 默认的位置编号
`1`、`2`、`3`…。插件没有关闭 tab 命名的配置项，因此在本地 checkout 的 `internal/app/app.go` 的
`nameTab` 开头加了无条件 `return` 并重新编译（pane 命名与 topic 走 `namePanes` /
`reportTopics`，不受影响）。补丁不在本仓库内，重装或升级插件后需要重新打：

```bash
cd ~/.config/herdr/plugins/github-installations/herdr.auto-title-*/*/checkout
# 在 nameTab 的 `if pass.TabLocked(tab.ID) {` 之前加：if true { return }
nix shell nixpkgs#go -c go build -o herdr-auto-title ./cmd/herdr-auto-title
herdr plugin action invoke herdr.auto-title.restart
```

Herdr 0.9.5 无法清除 tab 的自定义名，插件写过名字的旧 tab 需要手动
`herdr tab rename <tab_id> <位置>`
改成编号；这类名字是固定的，关掉前面的 tab 后不会自动重排，新建的 tab 则始终显示实时位置。
`herdr plugin disable` 不会结束已运行的插件进程，需配合 restart 或重启 server。

基础配置设置 `prompt_new_tab_name = false`：新建 tab 不弹命名框，直接显示位置编号。

插件安装时用 Go 从源码构建，本机未全局安装 Go，并且 `proxy.golang.org`
访问超时，因此临时提供 Go 并改用国内代理：

```bash
GOPROXY=https://goproxy.cn,direct nix shell nixpkgs#go -c \
  herdr plugin install kryptamine/herdr-auto-title --ref v0.14.0 --yes
herdr plugin action invoke herdr.auto-title.restart
```

升级时把 `--ref` 换成新 release tag 重跑这两行；移除用
`herdr plugin uninstall herdr.auto-title`。插件只通过 Herdr socket 读写标签，不联网。

## Agent 集成

已安装 `claude`（v11）与 `omp`（v10）集成，`herdr integration status` 可查看：

- `claude`：在 `~/.claude/hooks/herdr-agent-state.sh` 安装 hook，并在 `~/.claude/settings.json`
  注册（该文件不由 Nix 管理）。作用是上报会话 ID，使 Herdr
  server 重启或升级后能恢复原 Claude 会话；auto-title 也据此按会话命名。Claude 的状态仍由读屏判断。
- `omp`：见上文“通知与 Agent 集成”。

Herdr 升级后若 `integration status` 显示 `outdated`，重新执行 `herdr integration install <name>`。

## 从手机连接

Herdr 不要求手机安装专用 App。手机使用任意 SSH 客户端登录运行 Agent 的主机，再运行 Herdr：

```bash
ssh vitus@<apollo 的 Tailnet IP 或主机名>
herdr
```

Herdr
TUI 会适配窄屏。手机与主机需要先具备可用的 SSH 路径；使用 Tailnet 地址时，两端还需要处于同一 Tailscale 或 Headscale 网络。

手机退出 SSH 不会停止 Herdr 后台会话。重新 SSH 登录并运行 `herdr` 后，会回到同一会话。

## 验证

部署配置前可执行低风险验证：

```bash
nix eval --raw .#nixosConfigurations.apollo.pkgs.herdr.version
nix eval --raw .#nixosConfigurations.apollo.config.home-manager.users.vitus.programs.nushell.package.version
nix build .#nixosConfigurations.apollo.config.home-manager.users.vitus.home.activationPackage --no-link --print-build-logs
nix eval .#evalTests --show-trace --print-build-logs --verbose
```

部署后重新加载配置，新建一个 Pane，再确认其前台进程和字形输出：

```bash
herdr server reload-config
herdr pane list
herdr pane process-info --pane <pane_id>
printf "┌─┬─┐ │ 中文  │ └─┴─┘\n"
```

`process-info` 中的新 Pane Shell 应为 `nu`，输出中不应再出现 Bash 的 `shopt` 错误或字面量 `\[\]`。

本次配置修改不执行 `just local`，因此不会自动切换当前 NixOS generation。

## 更新与回滚

Herdr 二进制为官方安装、自管理更新：本机直接运行 `herdr update`，与仓库 `nixpkgs`
输入无关；仓库只负责 `~/.config/herdr/config.toml` 的声明式生成。

如需回到只读 symlink 部署，把 `home.activation.herdrConfig` 换回
`xdg.configFile."herdr/config.toml".text = …`，部署前先删除可写的
`~/.config/herdr/config.toml`，否则 Home
Manager 会因目标已存在而拒绝链接；此后 radar 将无法写入托管块。删除软件包或配置不会主动停止已经运行的 Herdr
server；如需结束会话，先确认 Pane 内没有需要保留的进程，再执行：

```bash
herdr server stop
```

## 参考

- [Herdr `0.9.5` 配置文档](https://herdr.dev/docs/configuration/)
- [Herdr 插件市场](https://herdr.dev/docs/marketplace/)
- [herdr-radar](https://github.com/hhdebb/herdr-radar)
- [Herdr 安装文档](https://herdr.dev/docs/install/)
- [Herdr 工作方式与手机 SSH 接入](https://herdr.dev/docs/how-to-work/)
- [Herdr 持久化与远程连接](https://herdr.dev/docs/persistence-remote/)
