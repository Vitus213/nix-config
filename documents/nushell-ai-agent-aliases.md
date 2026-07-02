# Nushell AI Agent 快捷命令

当前配置通过用户级包管理器安装更新频繁的 AI Agent CLI，并在 Nushell 启动配置里提供全权限快捷命令。

配置入口：

- `home/base/core/npm.nix`：安装 `bun` 和 `pnpm`，并配置 `npm install -g` 的用户级安装前缀为
  `~/.npm`。
- `home/base/core/shells/default.nix`：把 `~/.npm/bin` 和 `~/.bun/bin` 加入 shell `PATH`。
- `home/base/tui/shell/default.nix`：定义 Nushell 快捷命令。

## 安装和更新

这些 CLI 更新频繁，不通过 Nix 固定版本。

Pi / Oh My Pi 使用 Bun 安装或更新：

```bash
bun install -g @oh-my-pi/pi-coding-agent@latest oh-my-pi@latest
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
oh-my-pi --version
opencode --version
```

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
```
