# Magpie 共享模型网关

## 当前配置

全屋只维护一个 [yetone/magpie](https://github.com/yetone/magpie) 实例，2026-11-08 从 Athena 迁到
**J1900（Debian 13 amd64，`192.168.100.3`）**，版本固定 `0.1.1846`。使用官方
`magpie-cli-linux-amd64` headless 产物，保留 CLI、TUI 和浏览器管理，不安装 GTK /
WebKit。Apollo、Athena、Artemis 均为客户端；Artemis 当前离线，尚未部署新地址。

配置入口：

- J1900 `/usr/local/bin/magpie`：官方同版产物；SHA256
  `e006a1101432a0f214a83343cdd3c34de36ace53a39247d4b1cbfa3b9442c005`。
- J1900
  `/home/vitus/.config/systemd/user/magpie.service`：用户服务、监听地址与启动环境；`linger=yes`。
- J1900 `/home/vitus/.config/magpie`：唯一权威的上游、路由、调用方 key、订阅登录状态。
- `home/base/core/omp-sync.py`、`omp-models.yml.in`：客户端地址选择与动态目录声明。
- Athena 原 `magpie.nix` 导入和服务声明已删除；旧数据仅作回滚点，不得与新实例双活。

| 项目     | 值                                                                               |
| -------- | -------------------------------------------------------------------------------- |
| 网关地址 | J1900 本机 `http://127.0.0.1:3425/v1`；其他客户端 `http://192.168.100.3:3425/v1` |
| 管理页面 | `127.0.0.1:3430`（仅 J1900 本机，走 SSH 隧道）                                   |
| 鉴权     | 局域网请求必须带 Magpie 网关 key；回环免 key                                     |
| 状态目录 | `/home/vitus/.config/magpie`（J1900）                                            |

服务以 `vitus` 用户级 systemd unit 运行，已 `enable` 且
`linger=yes`，不依赖 SSH 或图形登录会话。`MAGPIE_ADDR=0.0.0.0:3425`
开放 LAN 接入；管理页面不对外监听。

## 使用

客户端连接（OMP 已按此配置）：

```yaml
magpie:
  baseUrl: @MAGPIE_BASE_URL@
  api: openai-completions
  apiKey: @MAGPIE_KEY@
  headers:
    User-Agent: omp
  compat:
    promptCacheSessionHeader: x-session-affinity
  discovery:
    type: openai-models-list
```

`@MAGPIE_BASE_URL@` 由 `omp-sync.py` 按本机 hostname 决定（忽略域名后缀与大小写）：`j1900` 用
`http://127.0.0.1:3425/v1`；包括 Athena 在内的其他主机用
`http://192.168.100.3:3425/v1`。网关 key 仍来自 agenix `omp-keys.age` 的 `magpie:` 行，占位符
`@MAGPIE_KEY@`，不在仓库留明文。

网关所在机必须使用回环免 key，其他客户端必须携 key；不能把客户端自己的 `127.0.0.1`
误当远端网关。0.1.1846 的 agent sync 会将网关自身 LAN 地址写成
`auth: none`，与非回环鉴权冲突；原 Athena 的复现保留在本文末尾历史记录中。

```sh
omp models refresh magpie           # 目录或路由变更后
ssh j1900 magpie models             # 在唯一网关上查看目录
ssh -L 3430:127.0.0.1:3430 j1900    # 管理页只经 SSH 访问
```

J1900 上的日常运维：

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
`127.0.0.1:3425` 连接 Athena；该地址代表 Apollo 自己。Athena 本机相反：用 `127.0.0.1:3425`
（回环免 key），模板由 hostname 自动区分。

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
`magpie/auto/gpt-6.1-sol` 当前使用 order 路由：codex → sci-openai → sci-plus，`stays=auto`；
`magpie/group/sol-any` 是另一组独立的 order 路由。`auto` 是网关模型 ID 的一部分，与 OMP 的
`--thinking auto` 无关。旧会话启动时已固定模型范围，F5 不能重建该范围。

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

`magpie` provider 的唯一目录来源是 J1900 网关的 `/v1/models`。客户端使用动态 `openai-models-list`
发现；`magpie/**`
只是允许嵌套 ID 通过白名单，不会重新启用网关关闭的型号。统一模板让包括原网关 Athena 在内的客户端连接
`192.168.100.3:3425` 并携带 key。

在 Magpie 管理界面选择、开启或关闭 provider 型号、路由组后，需要让客户端刷新目录：

```sh
omp models refresh magpie
```

随后重开普通 OMP 会话，启动时的模型范围才会按新目录重建。OMP
18.13.1 的已有会话并非实时订阅网关开关；有固定 scope 时 F5 不重建 scope，不能用旧会话仍显示缓存条目来判断 Magpie 开关失效。用户关闭过的型号不应通过复制旧静态目录重新加入。

实际开关复验：关闭 Claude 订阅条目后，网关目录与 Apollo、Athena 两台新 TUI 的 Magpie 分组均为 25 项，逐项模型 ID 完全一致，`magpie/claude/*`
均不存在。此数量只是当时的开关快照，不是固定目标；后续以 Magpie 当前目录为准。其他 OMP 直连 provider 与 Magpie 是独立入口，不受 Magpie 的开关控制，本次未删除它们或改变默认角色。

### Sol 共同工作窗口与实测边界（2026-10-29）

Athena 上三条 `gpt-6.1-sol` 通道统一声明 `500000` 的工作窗口，输出上限保留
`128000`。这是一致、保守的客户端预算，不是“实测硬上限恰好 500K”。自动组保留 Codex 优先的 order 及
`stays=auto`，按以下命令设置，不改账号、key、默认角色或其他型号：

```sh
magpie model context codex/gpt-6.1-sol 500000
magpie model context sci-openai/gpt-6.1-sol 500000
magpie model context sci-plus/gpt-6.1-sol 500000
magpie group set auto/gpt-6.1-sol routing=order stays=auto models=codex/gpt-6.1-sol,sci-openai/gpt-6.1-sol,sci-plus/gpt-6.1-sol
```

容量探针使用合成数据，首、中、尾各放校验标记；以 `o200k_base`
离线计数，再检查上游完成事件、usage 与三个标记，不把流式 HTTP
200 本身当作成功，也不通过路由组替换测试上游。

| 通道                  | 输入计数口径               | 结果                                     |
| --------------------- | -------------------------- | ---------------------------------------- |
| Codex                 | 上游报告 524143 token      | 完成，三个标记正确                       |
| Codex                 | 上游报告 528147 token      | 完成，三个标记正确                       |
| Codex                 | 离线正文 999981 token      | 拒绝：超出上下文窗口，未返回 input usage |
| Codex                 | 离线正文 1059975 token     | 同上，未返回 input usage                 |
| sci-openai / sci-plus | 各约 1027 token 的离线正文 | 两者均 EOF / 502，无法测量容量           |

可确认 Codex 支持上述 528147-token 输入；未精确定位硬边界，不能用目录的 500K 或 SCI 原手工覆盖的 1050K 代替实测。SCI 的小请求尚不可用，本次没有声称其 500K 容量验证通过。其窗口从旧覆盖值降低到共同工作预算；网关故障仍需上游恢复，改变窗口不会修复 EOF。

配置后 Auto 小请求实际只尝试 Codex 并成功；三台刷新目录后，新普通 OMP 的 `/model`
均显示该组为 500K。直连 SCI 的模板中仅两条 Sol `contextWindow`
回填为 500000，其余型号能力不变。Magpie 设置保存在 Athena 可写状态，生效不需要系统 rebuild；模板增量随正常部署更新安装的同步命令，勿用尚未更新的 store 模板回退直连设置。

已有约 70 万 token 的历史不会自动变短，也不会自动换掉旧会话的预算；继续前需完成上下文压缩或新开会话接续任务，再选择同一 Auto 组。本次未操作用户正在运行的 Boxlite 会话。恢复原预算时，SCI 两条可设回 1050000，Codex 用
`magpie model context codex/gpt-6.1-sol --reset`
移除本次覆盖，然后刷新各客户端并重开会话；这只恢复旧配置，不代表旧数值已验证。

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

OMP 自身的 OAuth 没有迁入客户端配置。需要新增订阅时，只在 J1900 网关授权：

```sh
ssh j1900 magpie accounts add codex
omp models refresh magpie
```

未完成授权前，不能把中转的 GPT 当成 Codex 订阅额度。

## 多机器规则

- 只维护 J1900 这一份上游、路由和订阅登录；其他机器只存网关 key。
- 不要把同一份订阅 refresh token 复制给多台独立网关同时刷新。
- 不要让 Magpie 的 Agents 页接管 OMP，否则它会把动态目录块改成静态清单。
- 新增客户端时在 J1900 执行 `magpie gateway-key add <name>`；当前客户端共用 key 仍来自
  `omp-keys.age` 的 `magpie:` 行，轮换时必须同步更新密钥包与客户端。

## 数据、安全与备份

`~/.config/magpie`（J1900）是应用可写状态：

- `providers.json`：上游 API key（0600）。
- `logins.json` 等：订阅凭据。
- `usage.jsonl`、`routing/`：用量与路由记录。
- `web.env`：管理页面 `MAGPIE_WEB_KEY`，只给本机 unit 读。

该目录不提交 Git，备份按密钥材料处理。网关 key 轮换在 J1900 执行
`magpie gateway-key rotate <id>`，再同步更新密钥包与各客户端。

局域网请求强制校验 key，但**无 key 的回环请求仍放行**；不要把 3425 或 3430 暴露到公网。

## 更新、验证与回滚

J1900 使用固定官方 headless 二进制，`noAutoUpdate=true`；不要直接追 latest。更新须先核对官方发布、CPU 兼容性、校验和及登录状态兼容性，再单独批准实施。Apollo 本地 CLI 的 Nix
overlay 不控制 J1900 服务版本。

### 2026-11-08 J1900 迁移验证

- 冷复制 `.config/magpie`、必要 `.cache/magpie` 和 `.codex/auth.json`，252 文件逐个 SHA256 一致。
- 保留 10 个上游、5 个路由组、2 份登录状态，全部 22 个对外模型 ID 集合一致。
- LAN 无 key 为 401，原 key 为 200；管理页仅回环且无管理凭据为 401。
- Auto DeepSeek 与 Codex 订阅真实推理均完成；Apollo 实际 OMP 调用返回 `J1900_OMP_OK`。
- Claude 订阅在迁移前已经 lapsed，原样保留；没有重新授权或以其他上游冒充验证成功。
- 私密冷备：Apollo `~/backups/20261108-j1900/magpie/` 及两端
  `/root/migration-j1900-20261108/magpie/`。
- 回滚先停 J1900；若新端 token 已刷新，先冷传最新凭据回源，不能直接启旧 token 备份。

### 以下为 Athena 部署历史（2026-10）

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

旧 Athena 数据保留用于回滚；若需恢复，先停 J1900，再按私密备份中的原 unit 与配置恢复，同步最新订阅凭据后才能启动。原 Nix 服务导入已移除，不能再按旧导入路径直接部署。

### 已知上游缺陷：agent sync 写出免鉴权地址却要求 key（0.1.1846）

症状：Athena 本机 OMP 调用 `magpie/auto/gpt-6.1-sol` 稳定返回 `401 no API key was sent`，而同一网关
`127.0.0.1:3425` 无 key 可用。

根因在 Magpie 自己的 OMP 接线，不在 OMP 或密钥：

- `internal/agent/omp.go` 的 `ompProviderAt` 无条件先写 `auth: none`，仅当
  `keyAt(gw) != gateway.Token` 时才改写成 `apiKey`。
- `keyAt`（`gatewaykey.go`）只在 `onAnotherMachine(gw)` 成立时返回 LAN
  key。网关所在机写自己的 LAN 地址（`192.168.100.11`）不算“另一台机器”，于是保留 `auth: none`。
- 网关对 `0.0.0.0:3425` 上的非回环来源一律要求 caller key，生成的配置因此被自家网关拒绝。

复现（隔离 HOME，`HOME=/tmp/magpie-repro/home`，不触碰运行配置）：用带 `apiKey` 的副本执行
`magpie sync`，4 秒内被改写为 `auth: none` 且保留 LAN 地址；仅把地址改为 `127.0.0.1` 后 `auth: none`
才是有效组合，同副本推理成功。

本项目规避方式：模板用 `@MAGPIE_BASE_URL@`，J1900 渲染回环地址，其他客户端（包括 Athena）渲染 J1900
LAN 地址（见
[omp 模型配置](./omp-models.md#magpie-共享网关)）。上游修复前，网关本机若改用自己的 LAN 地址，`magpie sync`
会在下次启动或 sync 时删掉 key，401 复发。上述 Athena 地址仅为迁移前的复现记录。
