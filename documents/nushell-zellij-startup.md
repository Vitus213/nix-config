# Nushell 与 Zellij 启动链路

本文记录当前 Nushell、fzf 和 Zellij 的启动关系，以及排查启动失败时的低风险验证方式。

## 当前版本

当前 `apollo` 配置求值出的相关版本：

| 组件    | 版本      | 来源                           |
| ------- | --------- | ------------------------------ |
| Nushell | `0.116.1` | 主 `nixpkgs` 的 `pkgs.nushell` |
| Zellij  | `0.46.0`  | 主 `nixpkgs` 的 `pkgs.zellij`  |
| fzf     | `0.75.0`  | 主 `nixpkgs` 的 `pkgs.fzf`     |
| Atuin   | `18.24.6` | 主 `nixpkgs` 的 `pkgs.atuin`   |

这些组件默认跟随主 `nixpkgs` 输入更新，不在仓库内单独固定版本。artemis 走 `nixpkgs-darwin`
输入（nixpkgs-unstable），当前为 Nushell `0.115.1`，与 apollo 的更新节奏不同。

Home Manager（master，2026-10-20 起）的 fzf Nushell 集成直接 `source` fzf 包自带的
`share/fzf/key-bindings.nu` 与 `completion.nu`（需 fzf ≥0.73），不再生成
`nushell-fzf-integration.nu`。 `programs.fzf.historyWidget.command = ""` 会写入
`$env.FZF_CTRL_R_COMMAND = ""`，上游脚本据此不绑定 Ctrl-R；Atuin 的集成在 `config.nu`
中排在 fzf 之后，Ctrl-R 仍由 Atuin 负责。

## 配置入口

- `home/base/core/shells/default.nix`：启用 `programs.nushell`，并让 Home Manager 管理
  `~/.config/nushell/config.nu` 和 `env.nu`。
- `home/base/core/core.nix`：启用 `programs.fzf` 和 `programs.atuin`；fzf 的 Ctrl-R history
  widget 被显式关闭，Ctrl-R 归 Atuin history 集成使用。
- `home/base/tui/shell/default.nix`：加载 `nu_scripts` 中的别名、Kubernetes 辅助模块和 AI
  Agent 快捷命令。
- `home/base/tui/zellij/default.nix`：启用 Zellij；仅交互式 Nushell 且 stdin/stdout 均为 TTY 时自动进入，继续排除 Emacs、已有 Zellij、Herdr 和 Kitty。退出 Zellij 后保留 shell。

## 启动顺序

终端模拟器先启动 Nushell。Nushell 读取 Home Manager 生成的
`config.nu`，其中会依次加载基础配置、主题、主机 secret、Zellij 自动启动片段、共享 shell 片段、fzf 集成、direnv、atuin 和别名。

Zellij 自动启动依赖 Nushell 配置先成功解析。如果 Nushell 在解析 `config.nu` 或被 `source`
的脚本时失败，Zellij 不会进入，终端也会失去 Nushell 中定义的快捷命令。

Bash 与 Nushell 统一保留已有 PATH，并追加 `~/.local/bin`、`~/.cache/.bun/bin`、
`~/.bun/bin`、`~/go/bin`、`~/.cargo/bin`、`~/.npm/bin`。Nushell 去重，Go/Cargo 路径不再只在四语言开发主机单独追加。

`programs.nushell.loadSessionVariables = false` 明确保留既有会话继承方式；此次不启用 Home Manager
26.11 新增的启动时 POSIX 环境转换，避免在清理中改变登录环境的加载顺序。

Home Manager 激活脚本中的空 GitHub
token 只跳过 auth 生成，继续后续激活；token 仍只在运行时读取，不进入 Nix store。`.gitconfig`
仅自动移除确认是旧 Home Manager generation 的链接，手写文件保留；它若覆盖 XDG
Git 设置，应由用户合并后再移除。`.npmrc` 和 GitHub token 的非受管文件在 `writeBoundary`
后、HM 链接前通过 `run`
备份一次，受管链接不重复备份；已有备份时终止迁移，避免覆盖。dry-run 不移动文件或写入 gh auth。

## nu_scripts 导入约束

`nu_scripts` 的 `modules/argx` 导出了一个名为 `parse` 的自定义命令。不能使用：

```nu
use modules/argx *
```

星号导入会把 `argx` 的 `parse` 放入当前作用域，并覆盖 Nushell 内建的 `parse`。Home
Manager 生成的 fzf 集成脚本会调用内建 `parse --regex` 解析 SSH host。如果全局 `parse`
已被覆盖，就会出现：

```text
The `parse` command doesn't have flag `regex`.
```

当前配置使用限定名导入：

```nu
use modules/argx
```

这样 Kubernetes 模块仍可通过 `argx parse` 使用辅助解析器，同时全局 `parse` 保持为 Nushell 内建命令。

## Ctrl-R 归属

Bash 和 Nushell 同时启用 fzf 与 Atuin shell 集成。当前配置保留 Atuin 的 Ctrl-R 历史搜索，并设置：

```nix
programs.fzf.historyWidget.command = "";
```

这样 Home Manager 仍会加载 fzf 的文件和目录选择集成，但不会再让 fzf 与 Atuin 同时注册 Ctrl-R。

## 验证

检查当前版本：

```bash
nu --version
zellij --version
fzf --version
```

低风险验证 Home Manager 生成的 Nushell 配置可解析：

```bash
env ZELLIJ=1 INSIDE_EMACS=1 nu -c 'print "nushell config ok"'
```

验证 `argx parse` 仍通过限定名可用：

```bash
nu -c '"kubectl get pods" | argx parse | to nuon'
```

这些环境变量可额外显式跳过 Zellij；非交互 `nu -c` 和无 TTY 的 SSH 也会被自动启动条件排除。

2026-11-15 已启动本轮实际生成的完整
`config.nu`，退出码为 0、stderr 为空；临时配置与假 Zellij 在控制 PTY 中验证自动启动、`attach -c`、返回后保留 shell，以及 Emacs/Zellij/Herdr/Kitty 四种排除。非交互与无 TTY 分支均未启动假 Zellij；未替换当前终端配置或现有会话。

## 回滚

如果后续 `nu_scripts` 移除 `argx parse` 的命名冲突，或仓库不再加载 Home Manager fzf
Nushell 集成，可以重新评估是否需要限定名导入。

当前不要回退到 `use modules/argx *`，否则会再次覆盖内建
`parse`，导致 fzf 集成和 Nushell 启动链路失败。

## 排查记录：HM 文件未部署导致 atuin/Nushell 报错（2026-09-08）

现象：`darwin-rebuild switch` 后每次启动 Nushell 报

```text
Error: nu::parser::unknown_flag
× The `job spawn` command doesn't have flag `-t`.
```

根因：`home/base/core/git.nix` 的 `home.activation.backupExistingGithubToken` 片段在
`~/.config/agenix/github_token` 已正确链接到 agenix 路径时执行 `exit 0`。`home.activation`
片段内联在激活脚本顶层，`exit` 会终止整个Home
Manager 激活，文件链接等后续步骤全部跳过——系统闭包里的新 generation从未落到
`$HOME`。Nushell 仍读取旧 generation 的
`config.nu`，其 atuin 集成由旧版 atuin（18.12.1）生成，包含 Nushell 0.113.1 不支持的
`job spawn -t atuin`。已改为空命令跳过已就绪场景，不再终止激活。

同类问题也适用于 auth 生成阶段的空 token；当前 `configureGhAuth` 使用局部条件跳过，不执行顶层
`exit`。

判定文件是否真的部署：查看 `~/.config/nushell/config.nu`
的修改时间。若停留在上一次成功激活的日期，说明 Home Manager 文件阶段未执行（可对比
`~/.local/state/home-manager/gcroots/current-home` 指向的 generation 与 `/run/current-system`
闭包内的 `home-manager-generation` 是否一致）。

## 排查记录：herdr 旧 default_shell 用 0.113.1 解析新 fzf 集成（2026-10-17）

现象：artemis 的 Herdr 新建 Pane 时 Nushell 报
`nu::parser::extra_positional`（`str lowercase`，位于 HM 生成的 `nushell-fzf-integration.nu:313`）。

根因：herdr server 长驻且只在启动/`reload-config` 时读配置，其内存中的 `default_shell`
是旧 generation 的 nushell-0.113.1 store 绝对路径；10-07
switch 后系统 Nushell 为 0.115.1、fzf 集成脚本需要 ≥0.114，旧二进制解析新 `config.nu`
报错。普通终端经 PATH 启动 nu，不受影响。

修复：`herdr server reload-config`（立即生效）＋ `terminal.default_shell` 改为
`/etc/profiles/per-user/vitus/bin/nu` 稳定 profile 路径。详见 [Herdr Agent 终端运行时](./herdr.md)
的排查记录。
