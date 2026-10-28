# Magpie 共享模型网关

## 当前配置

全屋只维护一个 [yetone/magpie](https://github.com/yetone/magpie) 实例，跑在 **Athena**，版本固定
`0.1.1846`，从源码构建 `nogui` 变体，保留 CLI、TUI 与浏览器管理界面，不链接 GTK /
WebKit。Apollo、Artemis 的 OMP 只作为客户端连接它，不各自再跑一份。

配置入口：

- `overlays/magpie/default.nix`：源码版本、源码 hash 与 Go 依赖 hash。
- `hosts/olympians-athena/magpie.nix`：安装包、用户服务与网关地址。
- `hosts/olympians-athena/home.nix`：导入用户模块。
- `hosts/olympians-athena/default.nix`：`linger` 与防火墙放行 `3425`。
- `home/base/core/omp-models.yml.in`：各客户端的 `magpie` provider。

| 项目     | 值                                              |
| -------- | ----------------------------------------------- |
| 网关地址 | `http://192.168.100.11:3425/v1`                 |
| 管理页面 | `127.0.0.1:3430`（仅 Athena 本机，走 SSH 隧道） |
| 鉴权     | 局域网请求必须带 Magpie 网关 key                |
| 状态目录 | `/home/vitus/.config/magpie`（Athena）          |

服务以 `vitus` 用户级 systemd unit 运行，已 `enable` 且
`linger=yes`，不依赖 SSH 或图形登录会话。`MAGPIE_ADDR=0.0.0.0:3425`
开放 LAN 接入；管理页面不对外监听。

## 使用

客户端连接（OMP 已按此配置）：

```yaml
magpie:
  baseUrl: http://192.168.100.11:3425/v1
  api: openai-completions
  apiKey: @MAGPIE_KEY@
  headers:
    User-Agent: omp
  compat:
    promptCacheSessionHeader: x-session-affinity
  discovery:
    type: openai-models-list
```

网关 key 存在 agenix `omp-keys.age` 的 `magpie:` 行，占位符 `@MAGPIE_KEY@`，由 `omp-sync.py`
注入；模板与仓库都不含明文。

```sh
omp models refresh magpie           # 目录或路由变更后
magpie models                       # Athena 上查看目录
ssh -L 3430:127.0.0.1:3430 athena   # 本机再打开 magpie web 给出的链接
```

Athena 上的日常运维：

```sh
systemctl --user status magpie
journalctl --user -u magpie -f
magpie web --gateway
magpie providers
magpie groups
magpie gateway-key list
```

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
只是允许嵌套 ID 通过本机白名单，不会重新启用网关已经关闭的型号。统一模板让客户端连接同一个
`192.168.100.11:3425` 网关并携带 agenix 注入的 key，不连接各自独立的 Magpie 实例。

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

Home Manager 管理该 unit，不要运行 `magpie daemon install` 或 `magpie daemon web on` 改写同名文件。

## 上游与凭据

Magpie 独立管理上游，不跟随 OMP 模板覆盖。当前已复用原有 8 个 API-key 上游：
`sci-openai`、`scitrace`、`sci-plus`、`sci-pro-special`、`gemini`、`glm`、`deepseek`、`newapi`。目录里实际 provider
ID 可能与来源名不同（例如 `gemini` 显示为 `gemini-2`），以 `magpie models` 为准。

客户端各自保留原有 provider 定义，只是多了一个 `magpie`
入口；OMP 自身的 OAuth（`openai-codex`、`anthropic`）没有被迁移。

Codex CLI 的 `~/.codex/auth.json` 只有 API key，没有 ChatGPT OAuth；OMP 的 `openai-codex`
登录在 OMP 自己的凭据库里，Magpie 发现不到。订阅需在 Athena 单独授权：

```sh
magpie accounts add codex
omp models refresh magpie
```

未完成授权前，不能把中转的 GPT 当成 Codex 订阅额度。

## 多机器规则

- 只维护 Athena 这一份上游、路由和订阅登录；其他机器只存网关 key。
- 不要把同一份订阅 refresh token 复制给多台独立网关同时刷新。
- 不要让 Magpie 的 Agents 页接管 OMP，否则它会把动态目录块改成静态清单。
- 新增客户端：在 Athena 上 `magpie gateway-key add <name>`，把值写进该机密钥（`omp-keys.age` 的
  `magpie:` 行由所有客户端共用同一把 key）。

## 数据、安全与备份

`~/.config/magpie`（Athena）是应用可写状态：

- `providers.json`：上游 API key（0600）。
- `logins.json` 等：订阅凭据。
- `usage.jsonl`、`routing/`：用量与路由记录。
- `web.env`：管理页面 `MAGPIE_WEB_KEY`，只给本机 unit 读。

该目录不提交 Git，备份按密钥材料处理。网关 key 在 agenix 密文里，轮换时在 Athena 执行
`magpie gateway-key rotate <id>`，再同步更新密钥包与各客户端。

局域网请求强制校验 key，但**无 key 的回环请求仍放行**；不要把 3425 或 3430 暴露到公网。

## 更新、验证与回滚

更新通过 Nix 改版本与两项 hash 重建，不使用 `magpie update` 替换只读 store 二进制。

已验证：

- 源码构建成功，`magpie --version` 为 `0.1.1846`；`just test` 与 `nixfmt --check` 通过。
- Athena 上 unit `enabled`/`active`，`linger=yes`，监听 `0.0.0.0:3425` 与 `127.0.0.1:3430`。
- 无 key 访问局域网 `/v1/models` 返回 401；带 key 返回 200，具体模型集合随 Magpie 开关变化。
- 禁用客户端重试/fallback 后，Apollo 返回 `ATHENA_MAGPIE_APOLLO_OK`，Artemis 返回
  `ATHENA_MAGPIE_ARTEMIS_OK`；两机普通新会话 `/model` 均出现 `magpie` 分组。
- 原有 provider 定义与默认角色未变；Apollo 本地实例已停用并删除 unit 软链。

athena 复验（2026-10-29）：`magpie/auto/glm-5.3-flash` 经网关返回 `MAGPIE_OK`、低思考档返回
`THE_OK`，`magpie/codex/gpt-6.1-sol`（Codex 订阅上游）返回
`CODEX_VIA_MAGPIE_OK`；OMP 日志确认 provider=magpie。局域网地址 192.168.100.11:3425 带 caller
key 可列出目录并完成真实推理；不带 key 返回 401。`omp models magpie` 目录 43 个模型（含 `auto/*`
路由组与 `codex/*`、`claude/*` 订阅上游）。

限制：经 Magpie 调用 `sci-openai/gpt-6.1-sol` 和 `scitrace/claude-haiku-4-5`
的烟测超时；绕过 Magpie 直接连接 `sub.scitrace.cc`
也发生 TLS 握手超时，因此未证明这两个中转的端到端可用性。未验证：复杂多轮工具调用、配额耗尽切换以及重启系统后的自启。

回滚：从 `hosts/olympians-athena/home.nix` 移除该导入与 `linger`/防火墙声明，停用 Athena
unit；确认备份后再删 `~/.config/magpie`。
