# Nushell AI Agent 快捷命令

当前配置通过用户级包管理器安装更新频繁的 AI Agent CLI，并在 Nushell 启动配置里提供全权限快捷命令。

配置入口：

- `home/base/core/npm.nix`：安装 `bun` 和 `pnpm`，并配置 `npm install -g` 的用户级安装前缀为
  `~/.npm`。当前 Bun 通过 `overlays/bun/default.nix` 临时覆盖到 `1.3.14`，满足最新版
  `@oh-my-pi/pi-coding-agent` 的 `bun >= 1.3.14` 要求。
- `home/base/core/shells/default.nix` 和 `home/base/core/shells/config.nu`：把 `~/.npm/bin`、
  `~/.bun/bin` 和 `~/.cache/.bun/bin` 加入 shell `PATH`。`omp` 当前由 Bun 提示安装在
  `~/.cache/.bun/bin`。
- `home/base/tui/shell/default.nix`：定义 Nushell 快捷命令。
- `~/.omp/agent/models.yml`：OMP 用户级模型 catalog 覆盖。当前 `llm-codex` provider 保留
  `gpt-5.5`，并新增 `gpt-5.6-sol`、`gpt-5.6-terra`，两者输入上下文按 `370K`、输出上限按 `128K`
  配置。
- `~/.omp/agent/config.yml`：OMP 用户级角色配置。当前 `enabledModels` 限定为
  `llm-codex/*`，`modelProviderOrder` 优先 `llm-codex`。

## 安装和更新

这些 CLI 更新频繁，不通过 Nix 固定版本。

Pi / Oh My Pi 使用 Bun 安装或更新：

```bash
bun install -g @oh-my-pi/pi-coding-agent@latest oh-my-pi@latest
```

如果尚未切换到包含 Bun `1.3.14` 的系统或 Home Manager 生成，最新版 `omp`
可先用官方预编译二进制安装：

```bash
curl -fsSL https://omp.sh/install | sh -s -- --binary
```

OpenCode 使用 npm 安装或更新：

```bash
npm config set prefix "$HOME/.npm"
npm install -g opencode-ai@latest
```

安装后应能看到：

```bash
bun --version
omp --version
opencode --version
```

`oh-my-pi` 作为配套包随 Pi / Oh My Pi 安装；当前常用入口是 `omp`。

## 当前 OMP 模型

| 角色                             | 当前模型                        |
| -------------------------------- | ------------------------------- |
| `smol`                           | `llm-codex/gpt-5.6-sol:high`    |
| `default` / `advisor` / `review` | `llm-codex/gpt-5.6-sol:xhigh`   |
| `slow` / `plan`                  | `llm-codex/gpt-5.6-terra:xhigh` |

`gpt-5.6-sol` 和 `gpt-5.6-terra` 都通过 `llm-codex` 自定义 provider 访问。模型元数据以
`~/.omp/agent/models.yml` 为准：`contextWindow: 370000`，`maxTokens: 128000`。

## 当前命令

| 命令 | 展开行为                                                 |
| ---- | -------------------------------------------------------- |
| `cy` | `codex --dangerously-bypass-approvals-and-sandbox`       |
| `oy` | 带 `OPENCODE_PERMISSION='{"*":"allow"}'` 运行 `opencode` |

`cy` 对应 Codex 的跳过审批和沙箱模式。`oy`
对应 OpenCode 的全允许权限配置，并会继续转发后面的参数，例如：

```nu
cy
cy "帮我检查这个仓库"
oy
oy run "帮我检查这个仓库"
```

这两个命令都适合只在可信工作区使用。

## 验证

```bash
nixfmt --check home/base/core/npm.nix home/base/core/shells/default.nix home/base/tui/dev-tools.nix home/base/tui/shell/default.nix
nu -c 'alias cy = codex --dangerously-bypass-approvals-and-sandbox; help aliases | where name == cy'
nu -c 'def --wrapped oy [...rest] { with-env { OPENCODE_PERMISSION: "{\"*\":\"allow\"}" } { print $env.OPENCODE_PERMISSION; print $rest } }; oy test'
omp --version
omp models llm-codex
omp config get modelRoles --json
omp --model llm-codex/gpt-5.6-sol --thinking low --no-tools --no-session -p "只输出 OK"
omp --model llm-codex/gpt-5.6-terra --thinking low --no-tools --no-session -p "只输出 OK"
```
