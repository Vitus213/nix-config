---
name: omp-provider
description:
  在 nix-config 中新增、修改或恢复 OMP provider、模型与认证配置时使用。规范 nix-config
  模板、my-secrets 密钥、flake 锁定、本机同步与回滚，防止覆盖已有通道、混用官方网关密钥或让
  openai-codex 等 OAuth provider 从新会话选择器消失。
---

# OMP provider 变更流程

## 目标与边界

默认是新增并存，不是替换原 provider。除非用户明确要求，不改默认模型、角色、fallback、其他 provider、OAuth 凭据或系统激活状态。

必须用中文沟通。先读仓库规则及下列实际文件，确认已安装 OMP 版本，再查该版本的官方模型配置文档与供应商 API 文档。不能把历史模型目录当成当前可用列表。

| 位置（相对 nix-config 根目录）                       | 职责                                                 |
| ---------------------------------------------------- | ---------------------------------------------------- |
| `home/base/core/omp-models.yml.in`                   | provider、模型、显示名与密钥占位符；不能出现真实密钥 |
| `home/base/core/omp-sync.py`                         | 将密钥行映射到占位符，检查缺失后生成配置             |
| `home/base/core/test_omp_sync.py`                    | 缺少密钥时拒绝生成等行为回归                         |
| `home/base/core/omp.nix`                             | agenix 路径、生成文件、软链与安装的同步命令          |
| `flake.nix` / `flake.lock`                           | `mysecrets` input 及其锁定版本                       |
| `secrets/README.md`                                  | identity、recipients、加解密与跨主机约定             |
| `documents/omp-models.md` / `documents/changelog.md` | 当前行为与主线变更记录                               |

另外两处不是这个仓库内的受管配置：

- `~/my-secrets/omp-keys.age`：API key 密文；recipients 以该仓库 `secrets.nix` 为准。
- `~/.omp/agent/config.yml`：本机可写普通文件，管理选择器白名单、排序、角色与 fallback。不能用 Nix
  store 只读文件接管，也不会自动分发到其他机器。

以下命令示例从 nix-config 根目录运行；标为 Bash 的代码在 Bash 中执行，不直接粘贴进 Nushell。不要自动提交、推送、切换系统或批量重启会话，除非用户已授权。

## 1. 明确认证与命名

先确定 provider ID、官方/中转端点、API 协议、模型 ID 和认证类型。

- **中转 API key**：用独立 provider ID，例如 `sci-openai`、`scitrace`、`newapi`。不能冒用
  `anthropic`、`openai-codex` 等官方身份，把 OAuth token 发给中转。
- **官方 API key**：例如 `deepseek` →
  `https://api.deepseek.com`，使用官方 key。同厂模型经过中转时仍用中转 key，不能根据模型名字推断 key 来源。
- **内置 OAuth**：例如 ChatGPT 的 `openai-codex`、Claude 的 `anthropic`。凭据归 OMP 登录流程，不进入
  `omp-keys.age`，不写进模板。仅改显示名时优先用只含 `name` 的 `modelOverrides`，不要顺带覆盖
  `api`、`apiKey`、`baseUrl` 或 `auth`。
- **真正无密钥的本地服务**才可用 `auth: none`；不能用它绕过官方 OAuth 可用性过滤。

`openai` 与 `openai-codex` 是不同身份；ChatGPT OAuth 不是 OpenAI API key。同样，`newapi/deepseek-*`
不是 `deepseek/deepseek-*` 官方直连。

把端点、认证分支、模型范围和明确不改的部分简短告知用户。已有明确授权时直接执行；只有新增与替换、改变默认路由等实质取舍才提问。

## 2. 建立安全基线

写入前记录：

1. 当前模板的 provider 集合、模型 ID、端点和模型能力。
2. 本机 `enabledModels`、`modelProviderOrder`、`modelRoles`、fallback，以及当前 profile /
   agent 目录。命名 profile 与默认 profile 不共用配置和认证。
3. OAuth 认证是否仍在：只能输出 provider ID、认证类型等非敏感元数据，不能直接展示 `omp auth export`
   的原始内容。
4. `/run/agenix/omp-keys`
   与密钥包中目标 key 行是否存在；只能报告存在性、行名或比较结果，不能打印值。
5. 现有 `models.yml`
   软链目标、生成文件权限和本机手改。渲染当前旧模板后与运行文件做结构比较；有额外本机改动时先保留并合并，不能直接从模板覆盖。

需要备份时，只在用户目录或受控临时目录保存，权限
`0600`，不能放进 Git 仓库。日志也可能含密钥或账号信息，引用前脱敏。

特别注意：`omp models --json` 是目录视图，不等于当前会话可选列表；显式 `--model`
调用成功也不证明普通新会话的 `/model` 能看到该 provider。

## 3. 按需修改 my-secrets

### 已有 key

目标 key 已存在且对目标官方端点有效时直接复用。不要为了新增模板块重新生成 key、重写整个密文或无意义更新 flake。若当前解密文件与锁定密钥包不一致，先定位版本差异。

### 新 key 或 key 更新

1. 在 `~/my-secrets` 按现有 identity 与 recipients 解密到受控内存或权限 `0600` 的临时文件。
2. 保留全部原有行，只增加或更新目标行。行格式为
   `provider-id: key`；映射规则是大写、连字符转下划线并加 `_KEY`，例如 `sci-openai:` →
   `@SCI_OPENAI_KEY@`。
3. 不把密钥放进命令参数、shell 历史、聊天、测试快照或仓库文件。不能以空 stdin 非交互运行 `agenix -e`
   / `agenix -r`，这会有清空明文的风险。使用真实 TTY，或 `secrets/README.md`
   约定的受控临时文件流程。
4. 按现有 recipients 重新加密并解密回读；在内存中验证新 key 正确、所有无关行未变、recipients 未减少。只输出校验结果。
5. 用户授权发布时，先提交并推送 my-secrets，再在 nix-config 运行
   `nix flake update mysecrets`。检查锁文件没有无关 input 更新；不要将两仓库的发布顺序倒置。
6. 需要更新 `/run/agenix/omp-keys` 时说明激活步骤；没有系统切换授权就不要执行 rebuild
   switch。不要把根目录不存在的解密文件伪造出来冒充 agenix 已部署。

仅新增 `omp-keys.age` 内的一行，不需要新增 agenix
secret 声明或改 recipients；只有文件/主机权限确实变化时才改对应 Nix 模块。

## 4. 增量修改 nix-config 与本机设置

### 模板与同步校验

- 在 `omp-models.yml.in` 的 `providers`
  下添加独立键，不替换已有 provider 块。沿用现有 API 字段和模型定义风格。
- `apiKey` 只能是 `@PROVIDER_KEY@` 占位符；在 `omp-sync.py`
  的缺失校验中**追加**该占位符，不能挤掉旧校验项。
- 从官方目录确认模型 ID、输入模态、上下文和输出上限。只配置真实可用型号；内置旧别名可能仍留在目录中，不能把它们误当成此次新增。
- 所有新增显示名使用 `provider · 模型名称`；请求模型 ID 不带显示名前缀。
- 检查新增 ID 是否与内置 provider 相同；官方直连允许有意覆盖同一身份，中转必须另起名字。不要复制一整份 OAuth 目录来掩盖发现/认证问题。
- 缺 key 时必须在写目标文件之前失败，并保留已有输出。保留或扩展现有行为回归；不要为显示文字、字段拷贝增加永久测试。

### 本机选择器

- 增量加入 `enabledModels`，否则 provider 即使已配置也可能不出现在 `/model` 或 Ctrl+P。
- 正式模型范围小且有旧别名时用精确 `provider/model-id`；确实要开放整组才用 `provider/*`。
- 增量加入 `modelProviderOrder`；它控制排序，不替代白名单或认证。
- 原有 `openai-codex/*`、`anthropic/*` 等条目必须保留。`disabledProviders`
  或路径级配置仍可能隐藏 provider，需一起检查。
- 默认角色和 fallback 不动，除非用户单独要求迁移。不要用“配置新通道”顺带替换原默认。

## 5. 先生成候选，再同步运行配置

1. 用仓库脚本和当前模板生成用户目录中的候选文件，预先设置
   `umask 077`。不要把含 key 的候选放进 nix-config，也不要交给会把内容存入 Nix store 的构建步骤。
2. 检查无残留占位符、YAML/OMP schema 有效、模型 ID 不丢失、所有无关 provider
   / 模型能力保持不变。比较时屏蔽密钥，不能输出完整运行文件或 diff。
3. 安装候选前再次确认运行文件与基线一致；若别的会话已改过，停止覆盖并重新合并。仅替换
   `.models.generated.yml`，保留 `models.yml` 的相对软链，最终权限 `0600`。
4. 激活后重开会话进行验收。原子替换文件能减少半写入窗口，但不能替代并发改动检查。

生成器接口是：

```text
python3 home/base/core/omp-sync.py <keys_file> home/base/core/omp-models.yml.in <candidate_output>
```

已安装的 `omp-sync-models` 绑定 Nix
store 中的脚本与模板。仓库改了但系统尚未更新时，再运行旧命令可能撤回新 provider 或显示名。明确告知这一点；要么暂用仓库脚本生成，要么在获准的正常系统更新后再使用安装的命令。不要擅自运行
`just local` 解决这个版本差异。

## 6. 必须通过的验收

- 运行 `python3 home/base/core/test_omp_sync.py` 等相关现有测试；新增 Nix 配置再按范围运行
  `just test` 或对应低风险 eval。不要为纯模板改动强行切换系统。
- 实际目录能识别新 provider / 模型，并核对调用端点属于预期官方网关。
- 用 OMP 真正调用新增模型，至少覆盖本次声明的型号及有差异的思考/非思考路径；临时关闭 retry 和
  `modelFallback`，防止请求悄悄走其他通道却被误报成功。`GET /models` 的 200 不能代替推理成功。
- **必须新开普通 OMP 会话，不传 `--model` 或临时 `--models` 掩盖问题**。打开
  `/model`，检查新增通道、`openai-codex`、`anthropic`
  和原有 API-key 通道仍在；再验证默认角色未被改变。记录实际 TUI 证据，不只依赖目录或显式调用。
- 仅更改名称时，比较前后 selector 与非名称字段；新增 provider 时，对所有原有 provider 做集合与配置不变检查，排除用户明确授权的变更。
- 发现 `No models match pattern`
  时先查当前 profile、白名单、认证元数据、目录发现/缓存与会话范围快照。可以刷新目录再重开会话验证；不能删除 OAuth 凭据、设置假 key 或
  `auth: none`，也不能只说“旧会话问题”而不做新会话验收。
- 删除自己的明文临时文件、烟测 overlay、临时会话和进程。备份如需保留须说明位置和权限，不留在 Git 内。

## 7. 文档、交付与回滚

更新 `documents/omp-models.md` 的当前 provider、端点、key 行与选择器说明，以及
`documents/changelog.md` 的配置入口、影响范围、验证和关联链接。新增专题文档时同步
`documents/README.md`，不要把过期描述继续当作当前行为。

交付必须明确：

- nix-config 改了哪些文件；my-secrets 是否修改、是否已发布与锁定；已有 key 复用时明确写“未改密钥包”。
- 本机配置是否已同步、是否仍受旧 store 同步命令覆盖；其他机器还需要哪些动作。
- 新模型及既有 OAuth 通道实际验收结果；没有做的检查与确切阻塞，不把显式调用通过当成选择器恢复。

回滚仅撤销这次新增的模板块、占位符校验与选择器条目，重新安全生成并验证旧 provider 集合。保留无关用户改动与现有 OAuth 登录；不要使用破坏性 Git 命令，不自动删除仍被别处使用的 key。密钥包确需回退时按两仓库发布与 flake 锁定顺序处理。
