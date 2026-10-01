# Nushell AI Agent 快捷命令

当前配置通过用户级包管理器安装更新频繁的 AI Agent CLI，并在 Nushell 启动配置里提供全权限快捷命令。

配置入口：

- `home/base/core/npm.nix`：安装 `pnpm`，并配置 `npm install -g` 的用户级安装前缀为 `~/.npm`。
- **OMP（bun 全局安装）**：`bun install -g @oh-my-pi/pi-coding-agent`，更新用
  `bun update -g @oh-my-pi/pi-coding-agent`，与 nix-config 解耦。全局 bin 在
  `~/.cache/.bun/bin`（bun 1.3.x 默认位置）。
- `home/base/core/shells/default.nix` 和 `home/base/core/shells/config.nu`：把 `~/.npm/bin`、
  `~/.cache/.bun/bin`、`~/.local/bin` 加入 shell `PATH`。
- `home/base/tui/shell/default.nix`：定义 Nushell 快捷命令。
- `~/.omp/agent/models.yml`：OMP 模型 catalog。由 nix-config 模板 `home/base/core/omp-models.yml.in`
  生成并软链接（key 经 my-secrets/agenix 注入；直接编辑可即时覆盖，`omp-sync-models`
  重置为模板版）。`bailian` provider 包含
  `qwen3.8-max`、`deepseek-v4-flash-0731`、`deepseek-v4-pro`、`deepseek-v4-pro-0813`、
  `glm-5.2-fast-preview`；`gemini` provider 走 scitrace 中转的 Gemini 系列（最强可用为
  `gemini-3.1-pro-high`）；另有 `scitrace`、`ccsci`、`sub2test`、`test-otel` 自定义 provider 与官方
  `deepseek`。
- `~/.omp/agent/config.yml`：OMP 用户级角色配置（可写普通文件，曾由 home-manager `programs.omp`
  声明式接管，因 store 只读导致 omp 写 `.lock` 失败已解绑）。`enabledModels` 覆盖 `bailian/*`
  与 scitrace/ccsci/sub2test/test-otel 各 provider；`bailian/*` 的 fallback 链为
  `scitrace/gpt-5.6-sol`。

## 安装和更新

OMP 使用官方推荐的 bun 全局安装，更新不经过 nix-config：

```bash
bun install -g @oh-my-pi/pi-coding-agent     # 安装
bun update -g @oh-my-pi/pi-coding-agent      # 更新
```

无需 `nix flake update omp` 或 `just local`。全局二进制位于 `~/.cache/.bun/bin/omp`，shell `PATH`
已含该目录（nushell `config.nu` / bash `default.nix`）。

OpenCode 使用 npm 安装或更新（更新频繁，不通过 Nix 固定）：

```bash
npm config set prefix "$HOME/.npm"
npm install -g opencode-ai@latest
```

安装后应能看到：

```bash
omp --version
opencode --version
```

当前常用入口是 `omp`；其可执行文件来自用户级 bun 全局安装，与 nix-config 解耦。

## 当前 OMP 模型

| 角色                 | 当前模型                             |
| -------------------- | ------------------------------------ |
| `slow` / `plan`      | `bailian/deepseek-v4-pro-0813:max`   |
| `advisor` / `review` | `bailian/qwen3.8-max:max`            |
| `smol`               | `bailian/deepseek-v4-flash-0731:max` |

以上角色均走 `bailian` provider（百炼 DashScope 兼容模式），`bailian/*` 的 fallback 链为
`scitrace/gpt-5.6-sol`。模型元数据以 `~/.omp/agent/models.yml` 为准。

## Gemini provider（scitrace 中转）

`gemini` provider 指向 `https://sub.scitrace.cc`，`api` 为 `openai-responses`，用独立 API key（与
`openai`/`anthropic`/`sci-plus` 各自的 key 不同）。未绑定任何 `modelRoles`，按需用
`--model gemini/<id>` 显式调用。

中转 `/v1/models` 列出 18 个 gemini id，实测只有 10 个通道可用，已全部写入 catalog：

| 模型                                         | 说明                                   |
| -------------------------------------------- | -------------------------------------- |
| `gemini-3.1-pro-high` / `gemini-3.1-pro-low` | 当前该通道最强，thinking 档位 low/high |
| `gemini-3.7-flash-high/-medium/-low`         | flash 系列最新可用                     |
| `gemini-3.6-flash-high/-medium/-low/-tiered` | flash 次新                             |
| `gemini-3.1-flash-lite`                      | 轻量                                   |

另 8 个 id（`gemini-3.8-flash-high/-medium/-low`、`gemini-3-flash`、
`gemini-3.5-flash-lite`、`gemini-2.5-flash`、`gemini-2.5-flash-lite`、
`gemini-2.5-flash-thinking`）返回 503
`No available accounts ... (channel pricing restriction)`，属中转账号池无对应权限，不写入 catalog。

### 窗口实测（10 个模型全测）

catalog 里的 `contextWindow: 1048576` / `maxTokens: 65536` 不是抄官方规格，是实测值。

**输入上限 1048576，全部 10 个模型一致。** 构造约 1.05M
tokens 的输入逐个打过，每个模型都返回 400 并点名同一个数字：
`The input token count exceeds the maximum number of tokens allowed 1048576`。 `gemini-3.1-pro-high`
另测了 100K/300K/600K/900K 唯一输入，均 200。

**输出上限约 65532**，由 `gemini-3.1-pro-high`（407s）和
`gemini-3.6-flash-high`（776s）两个模型撞到，数值完全相同，说明是通道统一上限。其余 8 个模型无法用提示词逼到上限：它们在几百到 2 万 tokens 就自行收尾（要求数到 30000 或重复 20000 行时，输出反而比要求 4000 行时更短），属模型不愿长输出，不是容量限制。这 8 个的真实上限**未实测到**，但
`max_output_tokens: 65536` 对全部 10 个模型都返回 200，配置值有效。

三个坑：

- `max_output_tokens` 网关完全不校验：填 `1000000` 返回 200，填 `200` 也拦不住模型吐出 2285~15630
  tokens（10/10 全部超出）。该参数在这条中转上不能当预算控制手段，64K 上限只在生成过程中静默生效。
- 被 64K 截断时仍报 `status: "completed"` 且
  `incomplete_details: null`，调用方无法靠status 区分“正常收尾”和“截断”，只能看 `output_tokens`
  是否贴着 65532。
- usage 会把缓存命中算进 `input_tokens`：900K 那次报 `input_tokens: 1497626` （含
  `cached_tokens: 598001`）仍然成功，说明 1M 上限针对唯一输入，usage 数字不能当容量判据。

支持 text + image 输入、流式与工具调用（实测 `/v1/responses` 返回 `function_call`、
`/v1/chat/completions` 返回 `tool_calls`）。

回滚：删除 `~/.omp/agent/models.yml` 中 `gemini:` 整段即可，备份在
`~/.omp/agent/models.yml.bak-20261001-gemini`。

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
omp models bailian
omp config get modelRoles --json
omp --model bailian/deepseek-v4-pro-0813 --thinking low --no-tools --no-session -p "只输出 OK"
omp models gemini
omp --model gemini/gemini-3.1-pro-high --thinking low --no-tools --no-session -p "只输出 OK"
omp --model gemini/gemini-3.1-pro-high --thinking high --no-session -p "用 bash 跑 'echo gemini-tool-ok'，然后只输出命令的 stdout"
```
