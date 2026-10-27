# omp 模型配置（models.yml）管理

本文档说明 `~/.omp/agent/models.yml` 的生成与管理机制。

## 架构

`models.yml` 是三部分合成的产物，由 nix-config 与 my-secrets 两个仓库协同管理：

| 位置                                          | 内容                                                                                   | 是否含明文 key |
| --------------------------------------------- | -------------------------------------------------------------------------------------- | -------------- |
| `nix-config/home/base/core/omp-models.yml.in` | 全部 provider / 模型定义，key 处为占位符（`@OPENAI_KEY@` 等）                          | 否             |
| `my-secrets/omp-keys.age`                     | 8 个 API key 的 age 加密包（含 glm、newapi；recipients 见 `my-secrets/secrets.nix`） | 否（密文）     |
| `~/.omp/agent/models.yml`                     | 上面两处合成后的实际配置（symlink → `.models.generated.yml`）                          | 是（仅本机）   |

**生成链路：**

```
nix-config 模板(占位符) ──▶ Nix store（只读）
my-secrets/omp-keys.age ──agenix──▶ /run/agenix/omp-keys（本机解密）
        ↓ home.activation.ompModels（home/base/core/omp.nix）
~/.omp/agent/.models.generated.yml  ←─ symlink ── models.yml
```

## 使用方式

- **直接手改**：编辑 `~/.omp/agent/models.yml` 即时生效，无需
  `just local`。重建系统不会覆盖（B 模式）。
- **从模板重置**（覆盖手改）：运行 `omp-sync-models`。
- **把改动同步到全平台**：将手改增量合并回
  `home/base/core/omp-models.yml.in`，提交并推送 nix-config；其他机器更新 flake 后在本地运行
  `omp-sync-models`（首次生成）。

### agent 改配置后的回填提醒

`config.yml`、`mcp.json` 等本机文件不经 nix 托管，改动只存在于当前机器。
为避免遗漏回填，两层规则已就位：

- `~/.omp/agent/RULES.md`（omp 全局规则，每个会话注入）：agent 改动
  `~/.omp/agent/` 下任何配置后，必须主动提醒用户把增量回填 nix-config。
- 本仓库 `AGENTS.md` 工作原则：在本仓库内改 omp 相关内容时，同样提示回填。

手动改完 `models.yml` / `config.yml` 而没走回填流程时，以本节为对照清单。

## 新增 provider / 模型（标准流程）

以后所有新模型都按此流程添加（以 glm 为例，2026-10-17 首次落地）：

1. **key 入库**（my-secrets）：解密 `omp-keys.age` 追加一行 `provider名: key` 后重新加密。⚠️
   `agenix -e/-r` 必须在**真实 TTY**
   中执行——非交互 stdin 下会把明文写空（血泪教训）；推荐流程：`age -d -i master_key omp-keys.age > /tmp/k`
   → 追加行 → 写一个 `cp /tmp/k "$1"` 的小脚本作 `EDITOR`，在 PTY 里跑 `agenix -e`。
2. **模板加块**（nix-config）：`omp-models.yml.in` 新增 provider 块（baseUrl / `apiKey: @XXX_KEY@` /
   `api` / models），同时在 `omp-sync.py` 的占位符校验列表加
   `@XXX_KEY@`（provider 名连字符→下划线）。
3. **提交推送**：先 my-secrets，再 nix-config `nix flake update mysecrets` 锁定新提交。
4. **生效**：`darwin-rebuild switch` / `nixos-rebuild switch`（重新解密 `/run/agenix/omp-keys`）→
   `omp-sync-models` 重新生成。
5. **验证**：`omp models find <名>` 能列出模型；必要时 curl 对应端点确认 key。

当前 glm provider：`https://open.bigmodel.cn/api/coding/paas/v4`（GLM Coding Plan，
`api: openai-completions`），模型 `glm-5.3` / `glm-5.3-flash` / `glm-5.2`，选择器 `glm/<model>`。

## scitrace provider（Claude 中转）

中转的 Claude 系列放在 `scitrace`
provider（`https://sub.scitrace.cc`，`api: anthropic-messages`），选择器为
`scitrace/<model>`；key 占位符沿用 `@ANTHROPIC_KEY@`（omp-keys 中的 `anthropic:` 行）。

该 provider **不能命名为 `anthropic`**：同名的自定义 provider 会覆盖 OMP 内置 `anthropic`
的 baseUrl。此时用 `/login` 登录 Anthropic 账号后，OMP 会把官方 OAuth token 发到中转站，所有
`anthropic/<model>` 请求返回 `401 {"code":"INVALID_API_KEY"}`。内置 `anthropic`
保留给官方 OAuth（`api.anthropic.com`）。

改名后需 `omp-sync-models` 重新生成，并重开已运行的 omp 会话（进程启动时读取配置）。验证：

```bash
omp -p --model anthropic/claude-opus-5-5 --no-tools "只回复 ok"
# ~/.omp/logs 最新日志中请求应指向 api.anthropic.com，而不是 sub.scitrace.cc
```

## newapi provider（国产五家中转，2026-10-27）

`newapi` provider 走自建 newapi 中转（`https://newapi.samuka007.top/v1`，
`api: openai-completions`），key 为 omp-keys 中的 `newapi:` 行，模板占位符
`@NEWAPI_KEY@`。每家国产模型选主力，选择器 `newapi/<model>`：

| 家 | 选择器 | 说明 |
| --- | --- | --- |
| DeepSeek | `newapi/deepseek-v4-pro`、`newapi/deepseek-v4.1-flash` | v4-pro 为旗舰推理；contextWindow 1M、maxTokens 393216 |
| GLM | `newapi/glm-5.3`、`newapi/glm-5.3-flash` | 与官方 `glm` provider 同型号互为备份（newapi 侧 maxTokens 需 ≤131072，上游按 GLM 限额校验） |
| Kimi | `newapi/kimi-k3.1-pro`、`newapi/kimi-k2.7-code` | |
| Qwen | `newapi/qwen3.8-max`、`newapi/qwen3.7-max` | |
| MiniMax | `newapi/MiniMax-M3` | |

注意事项：

- **baseUrl 必须带 `/v1`**。omp 对 openai-completions provider 的请求路径是
  `/chat/completions`（不含版本前缀），baseUrl 少写 `/v1` 时网关把错误路径吞成空 200 流，
  表现为模型空响应、`outputTokens=0`、empty-stop 重试耗尽。
- 中转目录里列出的型号不一定有可用通道（如 `qwen3-coder-480b-a35b-instruct`、
  `qwen3.5-plus` 实测 404），新增型号前先 `curl /v1/chat/completions` 实测。
- 此前直连官方的 `deepseek` provider（`api.deepseek.com`，`@DEEPSEEK_KEY@`）已由 newapi
  通道取代并从模板移除；config.yml 的 `retry.fallbackChains` 同步改为
  `newapi/* → sci-openai/gpt-5.6-sol`。
- 原 `openai` provider（scitrace 中转 GPT 系，`api: openai-responses`）已于 2026-10-27 改名为
  `sci-openai`（key 行与占位符同步改名），`openai` 这个名字让给将来的官方直连（内置 provider）。

回滚：移除模板 `newapi` 块与 `omp-sync.py` 的 `@NEWAPI_KEY@` 校验项、删去密钥包
`newapi:` 行重新加密，`config.yml` 恢复 `deepseek` provider 相关项后运行 `omp-sync-models`。

## 修改 key

1. 在 my-secrets 仓库更新明文并重新加密：`age -e -o omp-keys.age $(recipients) 明文文件`（recipients 取自
   `secrets.nix` 的 `systems`）。
2. 提交推送 my-secrets。
3. nix-config 更新 `mysecrets` flake input。
4. 目标机器重新解密（`darwin-rebuild switch` / `nixos-rebuild switch` 触发 agenix）后运行
   `omp-sync-models`。

## 约束与注意事项

- **key 不进 Nix store**：模板只含占位符；含明文 key 的文件只存在于用户目录，勿提交到任何 git 仓库。
- **不要硬链接到 store**：omp 需要在其 agent 目录写锁；`models.yml.lock`
  为目录内独立文件，指向用户目录生成文件的软链接不受影响。
- 幂等保护：`home.activation.ompModels` 在 `models.yml`
  缺失或不是软链接时生成（普通文件会被替换为软链接）；已是软链接则跳过。
- NixOS 主机需开启 `modules.secrets.desktop.enable`（apollo 已开启）才会解密
  `omp-keys`；缺少该文件时激活只打印警告，不阻断 rebuild。

## 一键部署的 sudo 自动化（sudoers 白名单）

`darwin-rebuild switch`（`just local`）需要 root；为让 omp
agent 无需人工输密码即可部署，仅对这条命令开放免密（最小权限，其余 sudo 照旧要密码）：

1. **一次性安装规则**（在你的终端执行，需输一次 sudo 密码）：
   ```bash
   # bash / zsh
   echo 'vitus ALL=(ALL) NOPASSWD: /nix/store/*/bin/darwin-rebuild switch' | sudo tee /etc/sudoers.d/nix-darwin && sudo chmod 440 /etc/sudoers.d/nix-darwin
   ```
   ```nu
   # nushell（不支持 &&，分两行执行）
   echo 'vitus ALL=(ALL) NOPASSWD: /nix/store/*/bin/darwin-rebuild switch' | sudo tee /etc/sudoers.d/nix-darwin
   sudo chmod 440 /etc/sudoers.d/nix-darwin
   ```
2. 规则用 `/nix/store/*/bin/darwin-rebuild switch`
   通配任意 store 哈希（darwin-rebuild 每次重建路径哈希会变），且只匹配 `switch` 子命令。
3. 回滚：`sudo rm /etc/sudoers.d/nix-darwin`。

⚠️ 该规则只放行 darwin-rebuild 切换，不涉及其他特权操作。

## 配置入口

- `home/base/core/omp.nix`：activation 生成逻辑 + `omp-sync-models` 脚本
- `home/base/core/omp-models.yml.in`：模型模板
- `secrets/darwin.nix`、`secrets/nixos.nix`：`age.secrets."omp-keys"` 声明（解密至
  `/run/agenix/omp-keys`，owner 为用户）
- `my-secrets/secrets.nix`：`"omp-keys.age".publicKeys`
