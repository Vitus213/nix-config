# Magpie 本地模型网关

## 当前配置

当前实际网关运行在 Athena（`192.168.100.11`），Apollo（`192.168.100.4`）作为局域网 OMP 客户端。Magpie 固定为
[yetone/magpie](https://github.com/yetone/magpie) `0.1.1846`，从源码构建 `nogui`
版本，保留网关、CLI、TUI 和浏览器界面，不包含 GTK / WebKit 桌面窗口。

配置入口：

- `overlays/magpie/default.nix`：源码版本、源码 hash 与 Go 依赖 hash。
- `hosts/olympians-apollo/magpie.nix`：安装包和 Home Manager 用户服务。
- `hosts/olympians-apollo/home.nix`：导入用户模块。
- `hosts/olympians-apollo/default.nix`：持久化 `~/.config/magpie`，权限 `0700`。

Athena 的 `magpie.service` 运行 `magpie serve --web=127.0.0.1:3430`，异常退出后重启。网关通过
`MAGPIE_ADDR=0.0.0.0:3425` 监听局域网；管理界面仅监听回环地址，固定登录 key 从
`~/.config/magpie/web.env` 读取，不进入 Nix
store。当前 unit 与仓库中的 Apollo 回环版定义不同，不能将仓库模块存在等同于 Athena 已由该模块部署。

局域网客户端必须发送有效的 gateway key；现有 key 名为 `omp-lan`，保存在 Athena 的
`~/.config/magpie/caller-keys.json`，不能使用管理界面的登录 key 代替。网关自身端口的回环请求允许无 key；访问
`192.168.100.11:3425`
即使来自 Athena 自己，也按远程请求校验，缺 key 返回 401。管理界面端口上的 API 请求同样需要 gateway
key。固定版本的
[鉴权规则](https://github.com/yetone/magpie/blob/v0.1.1846/docs/reference.md#connecting-anything-else)
明确区分这些入口。

服务设置 `DO_NOT_TRACK=1`，PATH 包含 Bun、npm、`~/.local/bin` 与 Home Manager
profile。Athena 已开启 linger，退出登录后用户服务保持运行。

## 启用与使用

Athena 当前用户 unit 链接到 Nix store；`~/.local/bin/magpie` 链接到固定版本二进制，
`~/.local/state/nix/profiles/magpie-unit`
保护该 unit 及其包闭包。仓库的安装和 preservation 定义仍位于 Apollo 模块中；这与 Athena 当前手工部署的 LAN
unit 是两处状态。本次仅修复 OMP 白名单和 SSH 别名，没有切换系统或改写网关 unit。

```sh
magpie web --gateway
```

已一次性复用原有 8 个 API-key provider，写入 Magpie 自己的 `providers.json`：
`sci-openai`、`scitrace`、`sci-plus`、`sci-pro-special`、`gemini`、`glm`、`deepseek`、`newapi`。上游 key 和端点来自现有已渲染配置，不重新申请 key、不改密钥包；此后在 Magpie 中独立维护，不会跟随 OMP 模板自动覆盖。Magpie 为避免与内置订阅重名，实际目录可使用不同 provider
ID（例如导入的 `gemini` 在目录中显示为 `gemini-2`），以 `magpie models` 为准。

Codex CLI 的 `~/.codex/auth.json` 当前只有 API key，没有 ChatGPT OAuth；OMP 的 `openai-codex`
登录在 OMP 自己的凭据库中，不能假定 Magpie 能自动发现它。需要在 Magpie 中单独授权，不能复制 OMP 的 refresh
token 给两个工具独立刷新：

```sh
magpie accounts add codex
omp models refresh magpie
```

授权需要用户在 OpenAI 页面完成登录；未完成前，不能把 API-key 上游的 GPT 当作 Codex 订阅。

`--gateway` 使用纯网关管理界面，隐藏 Agent 配置相关页面；无需由 Magpie 接管客户端配置。仍可用
`magpie web` 打开完整界面。

```sh
magpie --version
magpie providers
magpie models
magpie groups
magpie quota
magpie tui
systemctl --user status magpie
journalctl --user -u magpie -f
```

Home Manager 管理 `magpie.service`，不要运行 `magpie daemon install`、 `magpie daemon uninstall` 或
`magpie daemon web on` 改写同名 unit。启动与停止常驻服务使用
`systemctl --user start|stop|restart magpie`。

## 模型路由与 OMP 边界

Magpie 的路由组可以聚合不同 provider 的模型，并提供顺序切换、配额感知、轮转等策略；详见固定版本的
[Routing groups](https://github.com/yetone/magpie/blob/v0.1.1846/docs/reference.md#routing-groups)。
`home/base/core/omp-models.yml.in` 已声明独立的 `magpie` provider：

```yaml
magpie:
  baseUrl: http://127.0.0.1:3425/v1
  api: openai-completions
  auth: none
  headers:
    User-Agent: omp
  compat:
    promptCacheSessionHeader: x-session-affinity
  discovery:
    type: openai-models-list
```

> **注意（athena 现状）**：该块声明在 apollo 的模板中，但 athena 的 `~/.omp/agent/models.yml`
> 由本机手工合并维护（magpie 块同样适用，`auth: none` 无需密钥行）。仓库当前部署快照
> `/tmp/nixcfg-deploy`（提交 60e459ba，早于 magpie 提交 1fa972e8）尚不包含上述 unit 定义与模板块；athena 上运行的 unit、`MAGPIE_ADDR`、web.env 与 caller
> key 均为本机手工状态。下次部署 apollo 模板前不要用旧 store 的 `omp-sync-models`
> 重生成，否则 magpie 块会被移除。

OMP 18.13.1 通过 `/v1/models`
动态读取目录、上下文、输出上限和思考档，不在模板中复制模型列表。当前 OMP 入口使用 Chat
Completions，由 Magpie 转发或转换到上游协议；不能把协议转换视为所有原生功能、思考签名和多轮工具调用都已等价验证。新增 provider、模型或路由组后执行
`omp models refresh magpie`，再开新会话。

Athena 的 `enabledModels` 未设置白名单，发现的 Magpie 模型默认可选；Apollo 有白名单，必须使用
`magpie/**` 才能包含带 `/` 的嵌套模型 ID。选择器例如
`magpie/auto/glm-5.3-flash`、`magpie/codex/gpt-6.1-sol`。

Magpie 管上游和路由，Nix 模板管 OMP 的接入边界；不要在 Magpie 的 Agents 页再次接管 OMP，否则它会把动态目录块改成自己的静态清单。纯网关页面使用
`magpie web --gateway`。本机已安全重生成 `models.yml`，软链与 `0600` 权限保留。未更新系统前，旧的
`omp-sync-models` 仍可能从旧 store 模板生成配置并移除 Magpie，见
[OMP 模型配置管理](./omp-models.md)。

### Apollo Auto 路由可见性与 LAN 验收（2026-10-29）

Apollo 的 `~/.omp/agent/models.yml` 中，`magpie.baseUrl` 为
`http://192.168.100.11:3425/v1`，使用现有 gateway key 和 `openai-models-list` 发现。Apollo 不能用
`127.0.0.1:3425` 连接 Athena；该地址代表 Apollo 自己。

OMP 18.13.1 的 `enabledModels` 使用 Bun 路径 glob，`*` 不跨 `/`。`magpie/*` 无法匹配
`magpie/auto/gpt-6.1-sol`，也无法匹配 `magpie/group/sol-any`。修复为：

```yaml
enabledModels:
  # 保留其他 provider 条目。
  - magpie/**
```

此前目录命令列出 43 项，但普通新会话的 `/model` 只有 13 项：其他白名单如 `sci-openai/*`
意外匹配了 Magpie 模型的裸 ID `sci-openai/gpt-6.1-sol`，而 Auto /
Group 没有对应规则。这不是发现失败，也不需要开启特殊运行模式。实现依据为
[OMP glob 匹配](https://github.com/can1357/oh-my-pi/blob/v18.13.1/packages/coding-agent/src/config/model-resolver.ts#L133)
与 [Bun glob 语义](https://bun.com/docs/runtime/glob#supported-glob-patterns)。

使用时重开普通 `omp` 会话，输入 `/model`，搜索 `auto/gpt-6.1-sol`；完整选择器为
`magpie/auto/gpt-6.1-sol`。它使用 Magpie 的 smart 路由组，候选为 sci-openai、sci-plus、codex；
`magpie/group/sol-any` 则是 codex → sci-openai → sci-plus 的 order 路由。`auto`
是网关模型 ID 的一部分，与 OMP 的 `--thinking auto`
无关。旧会话启动时已固定模型范围，F5 不能重建该范围。

本次实际验收：

- Apollo → Athena 携 gateway key 读取 `/v1/models` 返回 HTTP 200。
- 修复前普通新 TUI 显示 Magpie
  13 项，搜索 Auto 无匹配；修复后新 TUI 显示 43 项，Auto 与 Group 均可搜索到。未使用 `--model` /
  `--models` 启动这些选择器验收会话。
- 从 Apollo 另发真实 OMP 请求，临时禁用 retry 和 OMP modelFallback，返回
  `APOLLO_AUTO_LAN_OK`；网关审计记录 `req=auto/gpt-6.1-sol`、`provider=codex`、HTTP
  200，客户端身份为 `omp-lan`。这次请求证明命中 Codex，未模拟配额耗尽或上游故障。
- 仅将 Apollo `config.yml` 的 `magpie/*` 改为 `magpie/**`，文件仍为 `0600`；默认角色仍是
  `magpie/sci-openai/gpt-6.1-sol:max`，其余角色、OAuth、key 和 retry 设置不变。临时会话与 smoke
  overlay 已清理。

本机白名单不由 Nix 生成，此处是配置回填记录，其他有白名单的客户端需同步同一规则。回滚仅把该条改回
`magpie/*` 并重开会话，但会重新隐藏嵌套路由。已安装的旧 `omp-sync-models`
仍可能覆盖本机 provider 地址与鉴权；正常更新系统前，不要用旧命令重置。

### Apollo 与 Athena 共同跟随 Magpie 的开关

`magpie` provider 的唯一目录来源是 Athena 网关的 `/v1/models`。两台 OMP 都使用动态
`openai-models-list` 发现，不维护第二份固定型号清单；Apollo 的 `magpie/**`
只是允许嵌套 ID 通过本机白名单，不会重新启用网关已经关闭的型号。Athena 通过回环、Apollo 通过 LAN 连接的是同一个网关，不是各自机器上独立的 Magpie 配置。

在 Magpie 管理界面选择、开启或关闭 provider 型号、路由组后，需要让客户端刷新目录：

```sh
omp models refresh magpie
```

随后重开普通 OMP 会话，启动时的模型范围才会按新目录重建。OMP
18.13.1 的已有会话并非实时订阅网关开关；有固定 scope 时 F5 不重建 scope，不能用旧会话仍显示缓存条目来判断 Magpie 开关失效。用户关闭过的型号不应通过复制旧静态目录重新加入。

实际开关复验：关闭 Claude 订阅条目后，网关目录与 Apollo、Athena 两台新 TUI 的 Magpie 分组均为 25 项，逐项模型 ID 完全一致，`magpie/claude/*`
均不存在。此数量只是当时的开关快照，不是固定目标；后续以 Magpie 当前目录为准。其他 OMP 直连 provider 与 Magpie 是独立入口，不受 Magpie 的开关控制，本次未删除它们或改变默认角色。

ChatGPT/Codex 订阅不等于 OpenAI
API 余额。Magpie 使用订阅凭据访问对应后端，可用模型、额度与授权范围由订阅及上游决定；第三方工具支持不构成上游授权保证。固定版本的
[订阅凭据说明](https://github.com/yetone/magpie/blob/v0.1.1846/docs/reference.md#signed-in-agents-as-providers)
还说明：导入 ChatGPT 账号会刷新 token，可能使原工具持有的刷新凭据失效。不要把同一份 refresh
token 复制给多台机器上的独立网关同时刷新。

此版本对外的 `/v1/responses` 支持 HTTP/SSE，但不支持 WebSocket upgrade（返回 426）；需要 Responses
WebSocket 的客户端不应在未经验证时整体迁入。

## 数据、安全与备份

`~/.config/magpie` 是应用可写状态，不使用 Home Manager 的只读配置软链接：

- `providers.json`：包含上游 API keys。
- `logins.json` 等：订阅凭据。
- `settings.json`、`profiles.json`：设置与方案。
- `usage.jsonl`、`routing/`：用量与路由记录。

整个目录由 Apollo 的 preservation 保存。不要提交到 Git；备份时按密钥材料保护。若启用配置前此目录已存在，应先按 preservation 的迁移要求保存已有数据，避免新挂载遮住旧目录。
`~/.cache/magpie` 未加入持久化清单，模型目录缓存和插件 Bun 运行时可能需要重新下载。

网关已启用 Bearer 鉴权（caller key 存 `~/.config/magpie/caller-keys.json`，目录 0700），但监听
`0.0.0.0:3425`
且 athena 防火墙默认关闭，持 key 的局域网设备都能调用；管理页面的登录 key 不等同于网关 key。不要把
`caller-keys.json` 明文提交或转发给不可信设备；收紧暴露面时把 unit 的 `MAGPIE_ADDR` 改回
`127.0.0.1:3425`（本机手工改动，仓库快照仍是回环地址）。

## 更新、验证与回滚

更新通过 Nix 调整版本及两项 hash 后重新构建，不使用 `magpie update` 替换只读 store 中的二进制。

已验证：

- 源码与 Go 依赖下载校验通过，原生构建成功，`magpie --version` 返回 `0.1.1846`。
- Apollo 求值结果包含对应包、用户服务和 `0700` 的持久化目录。
- `just test` 返回 `true`；改动的四个 Nix 文件通过 `nixfmt --check`。
- 独立用户服务已启用，`magpie healthcheck` 通过。
- 禁用 OMP retry / modelFallback 后，经 `magpie/newapi/deepseek-v4.1-flash` 真实返回
  `MAGPIE_CHAT_OK`，Magpie 审计记录为 `agent=omp`、对应 newapi 上游、HTTP 200。
- 未传 `--model` / `--models` 的普通新 OMP 会话实际打开 `/model`，可见 `magpie`，以及原有
  `openai-codex`、`anthropic`、API-key 通道；启动默认仍为 `openai-codex/gpt-6.1-sol`。
- 生成前后对比：所有原有 provider 定义不变；现有生成器回归通过。

athena 复验（2026-10-29）：`magpie/auto/glm-5.3-flash` 经网关返回 `MAGPIE_OK`、低思考档返回
`THE_OK`，`magpie/codex/gpt-6.1-sol`（Codex 订阅上游）返回
`CODEX_VIA_MAGPIE_OK`；OMP 日志确认 provider=magpie。局域网地址 192.168.100.11:3425 带 caller
key 可列出目录并完成真实推理；不带 key 返回 401。`omp models magpie` 目录 43 个模型（含 `auto/*`
路由组与 `codex/*`、`claude/*` 订阅上游）。

限制：经 Magpie 调用 `sci-openai/gpt-6.1-sol` 和 `scitrace/claude-haiku-4-5`
的烟测超时；绕过 Magpie 直接连接 `sub.scitrace.cc`
也发生 TLS 握手超时，因此未证明这两个中转的端到端可用性。未验证：复杂多轮工具调用、配额耗尽切换以及重启系统后的自启。

回滚时先停止用户服务，再移除 `home.nix` 的 Magpie 导入和专用持久化声明，重新应用配置。不要删除
`~/.config/magpie` 或其 `/persistent` 副本，除非已备份并确认不再需要其中的密钥与路由。
