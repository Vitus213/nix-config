# Herdr Agent 终端运行时

本文记录当前 Herdr 的安装来源、与 Zellij 的关系，以及从手机通过 SSH 接入持久会话的方式。

## 当前配置

Herdr 通过 `home/base/tui/dev-tools.nix` 加入 Home Manager 的 `home.packages`。

当前 `apollo` 配置求值结果：

| 组件    | 版本      | 来源                                       |
| ------- | --------- | ------------------------------------------ |
| Herdr   | `0.7.1`   | 主 `nixpkgs` 的 `pkgs.herdr`               |
| Nushell | `0.113.1` | Home Manager 的 `programs.nushell.package` |

Herdr 属于普通 CLI/TUI 工具，默认跟随主 `nixpkgs`
输入更新，不单独引入上游 flake 或第二套 Nixpkgs。部署 Home
Manager 配置后，Linux 与 macOS 的共享 TUI 配置都会提供 `herdr` 命令。

同一模块还通过 Home Manager 管理
`~/.config/herdr/config.toml`，让 Herdr 新建的交互式 Pane 与其他终端一致使用登录 Nushell：

```toml
onboarding = false

[terminal]
default_shell = "<Home Manager 管理的 Nushell>/bin/nu"
shell_mode = "login"

[ui.toast]
delivery = "herdr"
delay_seconds = 1
```

Herdr 的 `default_shell` 只接受可执行文件名或路径，不接受带参数的命令行。`shell_mode = "login"`
负责以登录 Shell 方式启动 Nushell；已有 Pane 会保留当前进程，直到手动替换 Shell 或重建 Pane。

## 启动与持久会话

在项目目录中启动：

```bash
herdr
```

Herdr 会启动或连接默认后台会话。分离客户端后，Herdr 后台服务器、Pane 和 Agent 进程继续运行：

```text
Ctrl+B Q
```

之后再次运行 `herdr` 即可重新连接。需要停止默认会话及其中进程时运行：

```bash
herdr server stop
```

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

## 通知与 Agent 集成（OMP）

Herdr 可以在后台 Workspace 的 Agent 完成或需要输入时弹出通知。当前配置为：

- `[ui.toast] delivery = "herdr"`：通知以 Herdr 应用内 toast 形式弹出。`system` 和 `terminal`
  模式依赖系统通知守护进程或外层终端转发，apollo 没有安装 dunst/mako 等服务，因此不使用。
- `[ui.sound]` 未显式配置，沿用默认 `enabled = true`，后台 Workspace 的 Agent 状态变化同时有提示音。

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
nix eval --raw '.#nixosConfigurations.apollo.config.home-manager.users.vitus.xdg.configFile."herdr/config.toml".text'
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

更新 Herdr 时正常更新主 `nixpkgs` 输入和锁文件，不使用
`herdr update`。Nix 安装由 Nix 管理，Herdr 自带更新器不负责该安装来源。

只回滚本次 Shell 修复时，从 `home/base/tui/dev-tools.nix` 移除 `xdg.configFile."herdr/config.toml"`
配置并重新构建 Home Manager；之后新 Pane 会重新回退到 `$SHELL`。完整移除 Herdr 时，还要从同一文件的
`home.packages` 中移除 `herdr`。删除软件包或配置不会主动停止已经运行的 Herdr
server；如需结束会话，先确认 Pane 内没有需要保留的进程，再执行：

```bash
herdr server stop
```

## 参考

- [Herdr `0.7.1` 配置文档](https://herdr.dev/docs/0.7.1/configuration/)
- [Herdr 安装文档](https://herdr.dev/docs/install/)
- [Herdr 工作方式与手机 SSH 接入](https://herdr.dev/docs/how-to-work/)
- [Herdr 持久化与远程连接](https://herdr.dev/docs/persistence-remote/)
