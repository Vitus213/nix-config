# Magpie 本地模型网关

## 当前配置

Apollo 的 Home Manager 配置安装 [yetone/magpie](https://github.com/yetone/magpie)，固定为
`0.1.1846`，从源码构建 `nogui` 版本。保留网关、CLI、TUI 和浏览器管理界面，不包含 GTK /
WebKit 桌面窗口。其他主机没有启用此服务。

配置入口：

- `overlays/magpie/default.nix`：源码版本、源码 hash 与 Go 依赖 hash。
- `hosts/olympians-apollo/magpie.nix`：安装包和 Home Manager 用户服务。
- `hosts/olympians-apollo/home.nix`：导入用户模块。
- `hosts/olympians-apollo/default.nix`：持久化 `~/.config/magpie`，权限 `0700`。

`magpie.service` 随用户登录启动，运行 `magpie serve`，异常退出后重启。网关固定监听
`127.0.0.1:3425`，不开放局域网端口。服务设置
`DO_NOT_TRACK=1`，PATH 包含用户的 Bun、npm、`~/.local/bin` 和 Home Manager
profile，供订阅桥接与插件查找 CLI。未配置 linger，不承诺用户退出后仍运行。

管理界面按需运行 `magpie web`，默认监听
`127.0.0.1:3430`，与常驻网关使用同一份配置。它会显示带登录 key 的本地链接；不设置 `MAGPIE_WEB_KEY`
时每次运行生成新的 key。不把管理密钥放进 Nix store 或用户 unit。

## 启用与使用

Apollo 已启用独立的 `magpie.service`，`magpie healthcheck`
通过；未切换整个 NixOS 系统。当前用户 unit 是由仓库 Home
Manager 配置单独求值、构建后链接的同一份文件， `~/.local/bin/magpie` 链接到固定版本的二进制。
`~/.local/state/nix/profiles/magpie-unit` 是该 unit 及其包闭包的 GC root。后续正常激活 Home
Manager 时使用仓库中的包与 unit 定义，不另建 `magpie daemon` 服务。

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

OMP 18.13.1 通过 `/v1/models`
动态读取目录、上下文、输出上限和思考档，不在模板中复制模型列表。当前 OMP 入口使用 Chat
Completions，由 Magpie 转发或转换到上游协议；不能把协议转换视为所有原生功能、思考签名和多轮工具调用都已等价验证。新增 provider、模型或路由组后执行
`omp models refresh magpie`，再开新会话。

本机 `config.yml` 只增量加入 `modelProviderOrder: [..., magpie]` 与
`enabledModels: [..., magpie/*]`。选择器例如
`magpie/newapi/deepseek-v4.1-flash`。所有原有 provider 定义和默认角色保留；原有 OAuth 凭据未迁移，用户同时修改的 retry 设置也不回退。

Magpie 管上游和路由，Nix 模板管 OMP 的接入边界；不要在 Magpie 的 Agents 页再次接管 OMP，否则它会把动态目录块改成自己的静态清单。纯网关页面使用
`magpie web --gateway`。本机已安全重生成 `models.yml`，软链与 `0600` 权限保留。未更新系统前，旧的
`omp-sync-models` 仍可能从旧 store 模板生成配置并移除 Magpie，见
[OMP 模型配置管理](./omp-models.md)。

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

默认本机网关不校验 API
key，任意本机进程都能调用它；回环绑定不是同机用户隔离。不要直接用端口转发、反向代理或 `--lan`
把它暴露出去；跨机器使用需要另行设置网关鉴权。管理页面的登录 key 也不等同于网关 key。

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

限制：经 Magpie 调用 `sci-openai/gpt-6.1-sol` 和 `scitrace/claude-haiku-4-5`
的烟测超时；绕过 Magpie 直接连接 `sub.scitrace.cc`
也发生 TLS 握手超时，因此未证明这两个中转的端到端可用性。未验证：Codex 独立授权后的推理、复杂多轮工具调用、配额耗尽切换以及重启系统后的自启。

回滚时先停止用户服务，再移除 `home.nix` 的 Magpie 导入和专用持久化声明，重新应用配置。不要删除
`~/.config/magpie` 或其 `/persistent` 副本，除非已备份并确认不再需要其中的密钥与路由。
