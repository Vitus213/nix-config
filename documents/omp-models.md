# omp 模型配置（models.yml）管理

本文档说明 `~/.omp/agent/models.yml` 的生成与管理机制。

## 架构

`models.yml` 是三部分合成的产物，由 nix-config 与 my-secrets 两个仓库协同管理：

| 位置                                          | 内容                                                                                            | 是否含明文 key |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------- | -------------- |
| `nix-config/home/base/core/omp-models.yml.in` | API-key provider / 模型定义及官方 OAuth 模型显示名覆盖，key 处为占位符（`@SCI_OPENAI_KEY@` 等） | 否             |
| `my-secrets/omp-keys.age`                     | 8 个 API key 的 age 加密包（含 glm、newapi；recipients 见 `my-secrets/secrets.nix`）            | 否（密文）     |
| `~/.omp/agent/models.yml`                     | 上面两处合成后的实际配置（symlink → `.models.generated.yml`）                                   | 是（仅本机）   |

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

`config.yml`、`mcp.json`
等本机文件不经 nix 托管，改动只存在于当前机器。为避免遗漏回填，两层规则已就位：

- `~/.omp/agent/RULES.md`（omp 全局规则，每个会话注入）：agent 改动 `~/.omp/agent/`
  下任何配置后，必须主动提醒用户把增量回填 nix-config。
- 本仓库 `AGENTS.md` 工作原则：在本仓库内改 omp 相关内容时，同样提示回填。

手动改完 `models.yml` / `config.yml` 而没走回填流程时，以本节为对照清单。

### 本机轻量角色（smol）

`~/.omp/agent/config.yml` 的 `modelRoles.smol` 使用
`newapi/deepseek-v4.1-flash:low`：通过已有 NewAPI 中转和网关 key 调用 DeepSeek
Flash，采用低思考档，不再让轻任务使用 Opus 的最高思考档。
[DeepSeek 官方思考参数说明](https://api-docs.deepseek.com/guides/thinking_mode) 支持
`low`；中转是否兼容以 OMP 实际请求为准。

这次仅改 `smol`，保留用户当前的默认角色
`newapi/deepseek-v4.1-flash:max`，以及其余角色、白名单、排序和 fallback。新开 OMP 会话会读取该设置；已运行会话不保证自动刷新角色。
`config.yml` 不受 Nix 托管，本节是本机变更的仓库回填记录，其他机器仍需手动设置同一个
`modelRoles.smol`，不会随 rebuild 自动同步。

验证：OMP 18.13.1 从保存的 `smol` 选择器及思考档发起真实请求，临时禁用 retry /
modelFallback 后，响应的 provider / model 为 `newapi` / `deepseek-v4.1-flash`，返回
`NEWAPI_SMOL_OK`；完整烟测进程耗时 11.42 秒，包含启动开销，不作为模型吞吐基准。临时配置已移除，未修改模板、密钥包或 flake，也未切换系统。

回滚：仅将本机 `modelRoles.smol` 改回 `scitrace/claude-opus-5-5:max`，再新开会话；保留其余设置。

### 本机自动模型 fallback

`~/.omp/agent/config.yml` 设置 `retry.modelFallback: false`，并移除 `retry.fallbackChains`。此前
`newapi/* → sci-openai/gpt-5.6-sol`
的自动备选链已关闭：原模型调用失败时，不再自动换到其他模型或 provider。`retry.enabled: true` 与
`retry.maxRetries: 10`
保留，可重试错误仍在同一模型上重试；不可重试错误直接报出。默认角色、`smol`、白名单和所有 key 不变。

这是本机手工配置，不属于 `models.yml`
模板；其他机器需自行同步这两个变更，不会随 rebuild 自动分发。重开 OMP 会话确保读取新设置。

验证：OMP 18.13.1 CLI 读取的有效开关为 false、备选链为空；受控本地 HTTP
400 失败烟测中，即使临时测试配置保留一条可用备选链，禁用开关后也只请求原模型、返回原错误，不访问备选模型。同一测试开启开关时确实会调用备选模型成功，排除了备选链本身不可用造成的假通过。烟测不调用真实供应商，不使用真实 key，临时服务和文件均已清理。

回滚：将 `retry.modelFallback`
改回 true，并按需恢复明确的备选链，再重开会话；只打开开关而没有链不会恢复原来的 NewAPI →
GPT 中转路由。语义依据：[OMP 18.13.1 重试策略](https://github.com/can1357/oh-my-pi/blob/v18.13.1/docs/non-compaction-retry-policy.md)。

## Magpie 共享网关

Athena 上的单一 Magpie 实例独立管理上游、账号和路由；OMP 模板只声明 `magpie`
provider，连接 `http://192.168.100.11:3425/v1`，用 `apiKey: @MAGPIE_KEY@` 与
`discovery.type: openai-models-list` 动态读取目录，不复制模型清单或上游 key。

`@MAGPIE_KEY@` 来自 `omp-keys.age` 的 `magpie:` 行，由 `omp-sync.py` 注入，缺失时拒绝生成。
Apollo、Artemis 共用同一把网关 key；各机 `.omp/agent/config.yml` 增量加入
`modelProviderOrder: [..., magpie]` 与 `enabledModels: [..., magpie/*]`。
原有 provider、OAuth 登录、默认角色和用户自己的 retry 调整保持不变。

目录或路由变更后运行 `omp models refresh magpie`，选择器形如
`magpie/newapi/deepseek-v4.1-flash`。回环 `127.0.0.1` 只对网关所在机器有效，
客户端必须用 Athena 的局域网地址。

网关 key 轮换、备份与已知限制见 [Magpie 共享模型网关](./magpie.md)。

## 新增 provider / 模型（标准流程）

统一操作规范见仓库技能：[omp-provider](../.agents/skills/omp-provider/SKILL.md)。它覆盖 API key /
OAuth 分流、两仓库发布顺序、增量合并、候选生成、选择器回归与回滚。在本仓库启动的新 OMP 会话会自动发现它，可用
`/skill:omp-provider` 调用。

- `nix-config` 管模板与占位符校验；`my-secrets` 只在新增或更新 API
  key 时修改。已有 key 可复用时，不重写密钥包、不无意义更新 flake。
- 本机 `config.yml` 的白名单与排序需增量更新，保留旧 provider、默认角色和 fallback。
- 验收必须包括普通新会话的 `/model`；目录列表和显式 `--model` 请求成功不能代替它。

当前 glm provider：`https://open.bigmodel.cn/api/coding/paas/v4`（GLM Coding Plan，
`api: openai-completions`），模型 `glm-5.3` / `glm-5.3-flash` / `glm-5.2`，选择器 `glm/<model>`。

## 模型显示名

模板统一使用 `provider · 模型名称`，例如 `sci-openai · GPT-5.6 Sol`、
`newapi · GLM 5.3`、`glm · GLM 5.3`。状态栏只显示模型名称时，也能辨认实际通道。

- 8 个 API-key provider 的 76 条模型定义直接设置 `models[].name`。
- 内置 `anthropic` / `openai-codex` 使用仅含 `name` 的 `modelOverrides`；不配置 `apiKey`、`baseUrl`
  或 `api`，保留官方 OAuth、端点与模型能力。OMP 升级新增内置型号后，需同步补充该型号的显示名覆盖。
- `id`、`provider/model-id` 选择器、角色与 fallback 引用均不变。显示名不是请求中的模型 ID。

本机已用仓库中的脚本与模板重新生成配置，无需切换系统。尚未 rebuild 时，已安装的 `omp-sync-models`
仍引用旧 Nix store 模板，再运行它会恢复旧显示名；可在仓库根目录用
`python3 home/base/core/omp-sync.py /run/agenix/omp-keys home/base/core/omp-models.yml.in ~/.omp/agent/.models.generated.yml`
按当前模板生成，文件权限保持 `0600`，然后重开 omp 会话。正常更新系统配置后，安装的 `omp-sync-models`
才会引用新模板。

回滚：恢复 `models[].name` 原名称，并移除两组仅用于命名的 OAuth
`modelOverrides`，再按同一生成流程同步。配置依据：[OMP 18.13.1 模型配置文档](https://github.com/can1357/oh-my-pi/blob/v18.13.1/docs/models.md)。

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

## deepseek provider（官方 API key 直连）

`deepseek` 使用官方 `https://api.deepseek.com`，协议为 `openai-completions`，与 `newapi`
中转并存。复用密钥包原有 `deepseek:` 行，模板引用 `@DEEPSEEK_KEY@`； `omp-sync.py`
缺失校验包含该占位符，缺 key 时拒绝写出配置。本次未修改 my-secrets 或 flake 锁定。

| 选择器                     | 显示名                                | 输入       | 上下文 / 输出上限 |
| -------------------------- | ------------------------------------- | ---------- | ----------------- |
| `deepseek/deepseek-flash`  | `deepseek · DeepSeek V4.1 Flash 1017` | 文本、图片 | 1000000 / 384000  |
| `deepseek/deepseek-v4-pro` | `deepseek · DeepSeek V4 Pro`          | 文本       | 1048576 / 393216  |

Flash 的正式 API ID 是 `deepseek-flash`，当前对应 V4.1-Flash-1017。本机 `enabledModels`
只精确加入上述两个选择器；OMP 内置目录仍保留的旧 Flash 别名不在白名单中。 `modelProviderOrder` 加入
`deepseek`，默认角色与 fallback 不变。

**密钥不能混用**：`newapi/deepseek-*` 使用 `newapi:` 网关 key；`deepseek/deepseek-*` 才使用
`deepseek:` 官方 key。不能把官方 key 发给 newapi。

验证：OMP 18.13.1 中临时关闭 retry / modelFallback，Flash 低思考模式返回
`DEEPSEEK_FLASH_OK`，Pro 非思考模式返回
`DEEPSEEK_PRO_OK`；缺 key 回归测试通过。刷新模型目录后，未指定 `--model` 的普通新会话 `/model`
同时显示 `deepseek`、 `openai-codex`、`anthropic` 与其余原有 API-key 通道，默认仍为
`openai-codex/gpt-6.1-sol`。

回滚：仅移除本次 `deepseek` 模板块、占位符校验和本机白名单 / 排序新增项，安全重生成；保留
`newapi`、所有 OAuth 凭据与原有官方 key。模型依据：[官方接入文档](https://api-docs.deepseek.com/)、
[Flash 1017 发布说明](https://api-docs.deepseek.com/news/news261017)。

## newapi provider（国产五家中转，2026-10-27）

`newapi` provider 走自建 newapi 中转（`https://newapi.samuka007.top/v1`，
`api: openai-completions`），key 为 omp-keys 中的 `newapi:` 行，模板占位符
`@NEWAPI_KEY@`。每家国产模型选主力，选择器 `newapi/<model>`：

| 家       | 选择器                                                 | 说明                                                                                        |
| -------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------- |
| DeepSeek | `newapi/deepseek-v4-pro`、`newapi/deepseek-v4.1-flash` | v4-pro 为旗舰推理；contextWindow 1M、maxTokens 393216                                       |
| GLM      | `newapi/glm-5.3`、`newapi/glm-5.3-flash`               | 与官方 `glm` provider 同型号互为备份（newapi 侧 maxTokens 需 ≤131072，上游按 GLM 限额校验） |
| Kimi     | `newapi/kimi-k3.1-pro`、`newapi/kimi-k2.7-code`        |                                                                                             |
| Qwen     | `newapi/qwen3.8-max`、`newapi/qwen3.7-max`             |                                                                                             |
| MiniMax  | `newapi/MiniMax-M3`                                    |                                                                                             |

注意事项：

- **baseUrl 必须带 `/v1`**。omp 对 openai-completions provider 的请求路径是
  `/chat/completions`（不含版本前缀），baseUrl 少写 `/v1`
  时网关把错误路径吞成空 200 流，表现为模型空响应、`outputTokens=0`、empty-stop 重试耗尽。
- 中转目录里列出的型号不一定有可用通道（如 `qwen3-coder-480b-a35b-instruct`、 `qwen3.5-plus`
  实测 404），新增型号前先 `curl /v1/chat/completions` 实测。
- 官方 `deepseek` 与 `newapi` 独立并存，分别使用各自的 key；本机已关闭自动模型 fallback，不再配置
  `newapi/* → sci-openai/gpt-5.6-sol` 备选链。
- 原 `openai` provider（scitrace 中转 GPT 系，`api: openai-responses`）已于 2026-10-27 改名为
  `sci-openai`（key 行与占位符同步改名），`openai` 这个名字让给将来的官方直连（内置 provider）。

回滚：仅移除模板 `newapi` 块、`omp-sync.py` 的 `@NEWAPI_KEY@`
校验和本机对应选择器项，再安全生成。保留官方 `deepseek` 和 OAuth 通道；`newapi:`
key 仍被 Hindsight 等服务使用，不随模型配置删除。

## openai-codex provider（ChatGPT 官方 OAuth，2026-10-28）

ChatGPT 官方认证由 `omp login` 管理，OAuth 凭据存在 omp 凭据库（provider 为 `openai-codex`、type
`oauth`），不进入模板或密钥包。模型能力来自内置 catalog；模板仅通过 `modelOverrides` 给显示名加
`openai-codex · ` 前缀，不重新定义模型能力或认证。

注意 `openai`（API-key 型，api.openai.com）与
`openai-codex`（ChatGPT 后端）是两个内置 provider：ChatGPT 账号 OAuth 只点亮
`openai-codex`；`openai` 没有 API key 时其 61 个目录模型均不算可用。

**模型选择器（/model、Ctrl+P）= 有可用凭据的 provider ∩ `enabledModels` 白名单**；
`modelProviderOrder` 只影响排序不过滤。因此 `enabledModels` 必须包含
`openai-codex/*`（2026-10-28 已加，`modelProviderOrder` 同步加
`openai-codex`），否则 OAuth 通道在选择器里整组不可见——表现为"openai 走官方 OAuth 却没模型可选"。

验证：`omp --model openai-codex/gpt-6-sol -p --no-session --thinking low 'Reply with exactly: ok'`
实际返回。

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
