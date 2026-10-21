# AI Agent 用量统计与 WakaTime

本文说明 GitHub profile（`Vitus213/Vitus213`）README 里 AI
agent 用量卡片的数据来源，以及 WakaTime 在本仓库中的接入方式。

## 组成

| 位置                                       | 作用                                                                                          |
| ------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `home/base/tui/agent-usage/agent_usage.py` | 采集、合并、渲染、推送（只用 Python 标准库）                                                  |
| `home/base/tui/agent-usage/default.nix`    | `agent-usage-report` 命令、每小时定时任务（Linux systemd / macOS launchd）、WakaTime key 接入 |
| `overlays/ccusage/`                        | 把 `pkgs.ccusage` 固定为官方 `20.0.39` 静态二进制                                             |
| `my-secrets/wakatime-api-key.age`          | WakaTime API key（单行）                                                                      |
| `secrets/nixos.nix` / `secrets/darwin.nix` | 解密 `wakatime-api-key`；NixOS 额外复制到 `/etc/agenix/wakatime-api-key`                      |
| profile 仓库 `agent-usage` 分支            | `data/<host>.json` 历史、`agent-usage.svg`、`agent-time.svg`、`summary.json`                  |

## 统计口径

| 指标     | Claude Code                                                                  | Codex                    | omp（`~/.omp/agent/sessions`）                             |
| -------- | ---------------------------------------------------------------------------- | ------------------------ | ---------------------------------------------------------- |
| token    | `ccusage claude daily --mode calculate`                                      | `ccusage codex daily`    | 脚本逐条 assistant 消息累加，按 `responseId` 去重          |
| 折算成本 | ccusage 按 LiteLLM 单价逐请求计算                                            | 同左（含 speed/flex 档） | 脚本按 LiteLLM 单价逐请求计算，prompt 超过分档阈值用高档价 |
| 活跃时长 | 全部会话事件时间戳合并后，相邻间隔 ≤ 15 分钟计入（与 WakaTime 默认超时一致） | 同左                     | 同左                                                       |

- 日期按 `Asia/Shanghai` 分组。
- **成本是公开 API 标价折算，不是实际账单**：订阅（Claude
  Max 等）和中转按各自规则计费，卡片底部有说明。
- omp 会话里自带的 `cost` 依赖 `models.yml`
  配置（大多为 0，DeepSeek 为非 USD 单价），因此不用它，统一按 LiteLLM 重新计价。模型名先精确匹配，再去掉
  `-0813` 这类日期后缀，同名多 provider 时优先第一方条目。找不到单价的模型计入
  `unpriced_tokens`，卡片上的成本会带 `*`。
- 不用 nixpkgs 的 ccusage 20.0.17：它早于 20.0.19（Codex 重放去重、reasoning 不重复计入）和 20.0.23
  / 20.0.26（Claude 跨会话去重）的修复，实测同一天的 Codex token 多算约 6%。
- Claude Code 默认只保留 30 天会话（`cleanupPeriodDays`），本机 `~/.claude/settings.json` 已改为
  `3650`。即使会话被清理，历史也保存在 `data/<host>.json`
  里：新统计覆盖旧值，但超过 25 天的日期如果新值更小，就保留旧值。

## 运行方式

- 定时任务：Linux 是 `systemd --user` 的
  `agent-usage-report.timer`（每小时，随机延迟 5 分钟，`Persistent`）；macOS 是 launchd agent
  `agent-usage-report`（每 3600 秒，日志在 `~/Library/Logs/agent-usage-report.log`）。
- 手动运行：`agent-usage-report`。只在本地渲染、不推送：`agent-usage-report --render-only /tmp/agent-usage`。
- 推送：读取 `/etc/agenix/github_token`（NixOS）或 `/run/agenix/github_token`（darwin），把
  `data/<本机>.json` 合并进 `agent-usage` 分支，重新汇总所有主机后渲染两张卡片，再用
  `--force-with-lease` 推成单个提交。多台主机同时推送时 lease 失败会自动重试 3 次。
- 两张卡片：
  - 有额度：`https://raw.githubusercontent.com/Vitus213/Vitus213/agent-usage/agent-usage.svg`（30 天/累计的活跃时长、token、成本，以及每日 token 柱状图）
  - 无额度：`https://raw.githubusercontent.com/Vitus213/Vitus213/agent-usage/agent-time.svg`（7 天/30 天/累计活跃时长，以及每日时长柱状图）
  - profile README 默认用有额度版本，无额度版本以注释形式写在它下面，切换时替换那一行即可。

## WakaTime

- Claude Code 装了官方插件 `claude-code-wakatime@wakatime`（4.1.0，用户级，`claude plugin`
  安装，不由 Nix 管理）。它在 hook 里调用 `wakatime-cli --sync-ai-activity`。`wakatime-cli`
  2.27 会顺带解析 Codex、omp 等 agent 的会话，把 AI 活动和行数上报到 WakaTime。
- `~/.wakatime.cfg` 依旧可变（preservation 软链接）。home-manager 激活时会写入
  `api_key_vault_cmd = <home.profileDirectory>/bin/wakatime-api-key`（NixOS / darwin 上是
  `/etc/profiles/per-user/vitus/bin/wakatime-api-key`），并删除明文 `api_key` 行。`wakatime-api-key`
  依次读取 `/etc/agenix/wakatime-api-key` 和 `/run/agenix/wakatime-api-key`。
- 旧的 `Waka Readme` workflow 已从 profile 仓库删除（默认 `GITHUB_TOKEN` 调不了
  `/user`，每天 403；README 里也没有写入标记）。README 也不再引用 github-readme-stats 的 WakaTime 卡片：没有数据时它只有 8px 高，会让整行错位。

## 新增主机或 agent

- 新主机：确认 `my-secrets/secrets.nix` 的 recipients 包含该主机，`modules.secrets` 已启用，然后
  `just local`。定时任务会推送 `data/<hostname>.json`，汇总时自动计入。
- 新 agent：在 `agent_usage.py` 的 `AGENTS` 里加一项，并在 `collect()` 和 `agent_session_files()`
  里接上数据源。

## 回滚

- 停用统计：从 `home/base/tui/agent-usage/` 移除模块，然后
  `just local`；README 删掉卡片那一行即可，`agent-usage` 分支可以保留，也可以删除。
- WakaTime：`claude plugin uninstall claude-code-wakatime@wakatime`；删除 `~/.wakatime.cfg` 里的
  `api_key_vault_cmd`。
- ccusage 版本：删除 `overlays/ccusage/`，回到 nixpkgs 版本（会重新多算 Codex）。
