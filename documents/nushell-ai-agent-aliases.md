# Nushell AI Agent 快捷命令

当前配置通过用户级包管理器安装更新频繁的 AI Agent CLI，并在 Nushell 启动配置里提供全权限快捷命令。

配置入口：

- `home/base/core/npm.nix`：安装 `pnpm`，并配置 `npm install -g` 的用户级安装前缀为 `~/.npm`。
- `home/base/core/omp.nix`：导入官方 flake `can1357/oh-my-pi` 的 Home Manager 模块，通过
  `programs.omp.enable = true` 安装 OMP。omp 由官方 flake 源码构建，版本固定于 `flake.lock`（当前
  `17.3.4`），不再依赖用户级 Bun 全局安装。
- `home/base/core/shells/default.nix` 和 `home/base/core/shells/config.nu`：把 `~/.npm/bin`
  加入 shell `PATH`。旧的 `~/.bun/bin`、`~/.cache/.bun/bin` 条目已随 omp 迁移移除。
- `home/base/tui/shell/default.nix`：定义 Nushell 快捷命令。
- `~/.omp/agent/models.yml`：OMP 用户级模型 catalog 覆盖。当前 `llm-codex` provider 保留
  `gpt-5.5`，并新增 `gpt-5.6-sol`、`gpt-5.6-terra`，两者输入上下文按 `370K`、输出上限按 `128K`
  配置。
- `~/.omp/agent/config.yml`：OMP 用户级角色配置。当前 `enabledModels` 限定为
  `llm-codex/*`，`modelProviderOrder` 优先 `llm-codex`。

## 安装和更新

OMP 通过官方 flake 安装，更新方式是刷新该 input 并重新切换系统：

```bash
nix flake update omp
# 然后重新构建/切换系统配置（如 just local）
```

官方 flake 首次构建需要本机源码编译 Rust
core 与 Bun 依赖（约 1400 个 derivation），后续版本更新通常只需增量编译。官方 flake 声明了
`nix-community.cachix.org` substituter（本仓库已信任），可减轻构建压力。

OpenCode 仍使用 npm 安装或更新（更新频繁，不通过 Nix 固定）：

```bash
npm config set prefix "$HOME/.npm"
npm install -g opencode-ai@latest
```

安装后应能看到：

```bash
omp --version
opencode --version
```

当前常用入口是 `omp`；其可执行文件来自 Home Manager 管理的官方 flake 包。

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
