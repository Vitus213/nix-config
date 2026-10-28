# Magpie 共享模型网关

## 当前配置

全屋只维护一个 [yetone/magpie](https://github.com/yetone/magpie) 实例，跑在 **Athena**，
版本固定 `0.1.1846`，从源码构建 `nogui` 变体，保留 CLI、TUI 与浏览器管理界面，
不链接 GTK / WebKit。Apollo、Artemis 的 OMP 只作为客户端连接它，不各自再跑一份。

配置入口：

- `overlays/magpie/default.nix`：源码版本、源码 hash 与 Go 依赖 hash。
- `hosts/olympians-athena/magpie.nix`：安装包、用户服务与网关地址。
- `hosts/olympians-athena/home.nix`：导入用户模块。
- `hosts/olympians-athena/default.nix`：`linger` 与防火墙放行 `3425`。
- `home/base/core/omp-models.yml.in`：各客户端的 `magpie` provider。

| 项目     | 值                                          |
| -------- | ------------------------------------------- |
| 网关地址 | `http://192.168.100.11:3425/v1`             |
| 管理页面 | `127.0.0.1:3430`（仅 Athena 本机，走 SSH 隧道） |
| 鉴权     | 局域网请求必须带 Magpie 网关 key            |
| 状态目录 | `/home/vitus/.config/magpie`（Athena）      |

服务以 `vitus` 用户级 systemd unit 运行，已 `enable` 且 `linger=yes`，不依赖 SSH
或图形登录会话。`MAGPIE_ADDR` 只绑 Athena 的局域网地址；管理页面不对外监听。

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

网关 key 存在 agenix `omp-keys.age` 的 `magpie:` 行，占位符 `@MAGPIE_KEY@`，由
`omp-sync.py` 注入；模板与仓库都不含明文。

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

Home Manager 管理该 unit，不要运行 `magpie daemon install` 或 `magpie daemon web on`
改写同名文件。

## 上游与凭据

Magpie 独立管理上游，不跟随 OMP 模板覆盖。当前已复用原有 8 个 API-key 上游：
`sci-openai`、`scitrace`、`sci-plus`、`sci-pro-special`、`gemini`、`glm`、`deepseek`、`newapi`。
目录里实际 provider ID 可能与来源名不同（例如 `gemini` 显示为 `gemini-2`），以
`magpie models` 为准。

客户端各自保留原有 provider 定义，只是多了一个 `magpie` 入口；OMP 自身的 OAuth
（`openai-codex`、`anthropic`）没有被迁移。

Codex CLI 的 `~/.codex/auth.json` 只有 API key，没有 ChatGPT OAuth；OMP 的
`openai-codex` 登录在 OMP 自己的凭据库里，Magpie 发现不到。订阅需在 Athena 单独授权：

```sh
magpie accounts add codex
omp models refresh magpie
```

未完成授权前，不能把中转的 GPT 当成 Codex 订阅额度。

## 多机器规则

- 只维护 Athena 这一份上游、路由和订阅登录；其他机器只存网关 key。
- 不要把同一份订阅 refresh token 复制给多台独立网关同时刷新。
- 不要让 Magpie 的 Agents 页接管 OMP，否则它会把动态目录块改成静态清单。
- 新增客户端：在 Athena 上 `magpie gateway-key add <name>`，把值写进该机密钥
  （`omp-keys.age` 的 `magpie:` 行由所有客户端共用同一把 key）。

## 数据、安全与备份

`~/.config/magpie`（Athena）是应用可写状态：

- `providers.json`：上游 API key（0600）。
- `logins.json` 等：订阅凭据。
- `usage.jsonl`、`routing/`：用量与路由记录。
- `web.env`：管理页面 `MAGPIE_WEB_KEY`，只给本机 unit 读。

该目录不提交 Git，备份按密钥材料处理。网关 key 在 agenix 密文里，轮换时在 Athena
执行 `magpie gateway-key rotate <id>`，再同步更新密钥包与各客户端。

局域网请求强制校验 key，但**无 key 的回环请求仍放行**；不要把 3425 或 3430 暴露到公网。

## 更新、验证与回滚

更新通过 Nix 改版本与两项 hash 重建，不使用 `magpie update` 替换只读 store 二进制。

已验证：

- 源码构建成功，`magpie --version` 为 `0.1.1846`；`just test` 与 `nixfmt --check` 通过。
- Athena 上 unit `enabled`/`active`，`linger=yes`，监听 `192.168.100.11:3425` 与 `127.0.0.1:3430`。
- 无 key 访问局域网 `/v1/models` 返回 401；带 key 返回 200（89 个模型）。
- 禁用客户端重试/fallback 后，Apollo 返回 `ATHENA_MAGPIE_APOLLO_OK`，Artemis 返回
  `ATHENA_MAGPIE_ARTEMIS_OK`；两机普通新会话 `/model` 均出现 `magpie` 分组。
- 原有 provider 定义与默认角色未变；Apollo 本地实例已停用并删除 unit 软链。

限制：经 Magpie 调用 `sci-openai/gpt-6.1-sol`、`scitrace/claude-haiku-4-5` 超时；
绕过网关直连 `sub.scitrace.cc` 也 TLS 握手超时，未证明该中转端到端可用。
未验证：Codex 独立授权后的推理、复杂多轮工具调用、配额耗尽切换；未执行整机
`nixos-rebuild switch`（Athena 当前 unit 由仓库求值后单独链接）。

回滚：从 `hosts/olympians-athena/home.nix` 移除该导入与 `linger`/防火墙声明，
停用 Athena unit；确认备份后再删 `~/.config/magpie`。
