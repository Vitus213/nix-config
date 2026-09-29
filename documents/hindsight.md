# Hindsight Agent 记忆后端

本文记录 Hindsight（agent 长期记忆服务）在本机的部署方式、LLM 配置，以及它作为 omp memory
backend 的接入与使用。

## 概述

[Hindsight](https://hindsight.vectorize.io/) 是开源 agent 记忆系统（PostgreSQL 存储），提供
`retain`（存入）/ `recall`（检索）/ `reflect`（综合问答）三类操作。omp 原生支持
`memory.backend: hindsight`，本机以 docker 容器本地运行服务端，替代 omp 默认关闭的记忆能力。

## 部署架构

```
┌────────────────────────────── macOS artemis ──────────────────────────────┐
│  colima（nix 包，Lima+QEMU 提供 docker daemon）                            │
│   └─ hindsight 容器（ghcr.io/vectorize-io/hindsight:latest）              │
│        ├─ REST API  :8888   ← omp memory backend（http://localhost:8888） │
│        ├─ Web UI    :9999                                                  │
│        └─ 嵌入式 PostgreSQL（pg0）→ 数据卷 hindsight-data                  │
└────────────────────────────────────────────────────────────────────────────┘
```

- 容器编排：`modules/darwin/hindsight/docker-compose.yml`
- 运行时与 CLI：`docker` / `colima` / `docker-compose` 通过 nix 安装（`modules/darwin/apps.nix` 的
  `environment.systemPackages`），不经过 brew。
- 数据持久化：docker 卷 `hindsight-data` 挂载到容器内 `/home/hindsight/.pg0`。

## LLM 与 Embedding 配置

| 项                             | 值                                                     | 说明                                                                                                                        |
| ------------------------------ | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `HINDSIGHT_API_LLM_PROVIDER`   | `openai`                                               | OpenAI 兼容协议                                                                                                             |
| `HINDSIGHT_API_LLM_BASE_URL`   | `https://dashscope.aliyuncs.com/compatible-mode/v1`    | 阿里云百炼兼容端点                                                                                                          |
| `HINDSIGHT_API_LLM_MODEL`      | `qwen3.8-flash`                                        | 与 omp `~/.omp/agent/models.yml` 的 bailian provider 中 `qwen3.8-flash` 同款                                                |
| `HINDSIGHT_API_LLM_API_KEY`    | `~/.config/hindsight/hindsight.env`                    | 0600 文件，手工维护，不入库                                                                                                 |
| `HINDSIGHT_API_LLM_EXTRA_BODY` | `{"chat_template_kwargs": {"enable_thinking": false}}` | qwen3.8-flash 思考模式禁止强制 `tool_choice`，hindsight 的 reflect/retain 走强制工具调用会 400 并重试 4 次，故关闭 thinking |
| Embeddings                     | 默认 `local`                                           | 镜像内建 ONNX 本地模型（BAAI/bge-small-en-v1.5），无外部 embedding API 依赖                                                 |

API key 文件格式（`~/.config/hindsight/hindsight.env`）：

```bash
HINDSIGHT_API_LLM_API_KEY=sk-ws-...
```

与 `~/.omp/agent/models.yml` 同为本地手工维护的用户级凭据文件。将来可迁入 `mysecrets` +
agenix（需要可用的 GitHub token 写私有 secrets 仓库）。

## 启动、停止与自启

服务生命周期由 nix 声明（`modules/darwin/hindsight.nix`），`just local` 部署后自动生效：

- `hindsight-colima`：登录时自动 `colima start`（幂等，VM 数据在 `~/.colima/`）。
- `hindsight-compose`：登录拉起重启容器，之后每 300s 兜底 `docker-compose up -d`
  一次（覆盖 daemon 未就绪/容器被误删场景），launchd 日志在
  `/tmp/hindsight-colima.log`、`/tmp/hindsight-compose.log`。

手动控制（调试用，注意用独立二进制 `docker-compose`——nix 的 docker 客户端不注册 `docker compose`
插件命令）：

```bash
cd modules/darwin/hindsight && docker-compose up -d      # 启动
cd modules/darwin/hindsight && docker-compose down       # 停止（数据卷保留）
```

容器配置了 `restart: unless-stopped`。状态查看： `docker ps` / `docker-compose logs -f hindsight`。

## 镜像拉取说明

首次启动镜像从 `ghcr.io/vectorize-io/hindsight:latest`
拉取。ghcr.io 直连在本机不稳定（下载中途断流），实际通过国内镜像站拉取后 tag 回官方名：

```bash
docker pull ghcr.nju.edu.cn/vectorize-io/hindsight:latest
docker tag ghcr.nju.edu.cn/vectorize-io/hindsight:latest ghcr.io/vectorize-io/hindsight:latest
```

## omp 集成（per-project-tagged）

启用配置在 `home/base/core/omp.nix` 的 `programs.omp.settings`（声明式，每次 home-manager
switch 覆盖 `~/.omp/agent/config.yml`；omp 运行时的 `/settings`
改动会在下次 switch 时恢复为声明值）：

```yaml
memory:
  backend: hindsight
hindsight:
  apiUrl: http://localhost:8888
  scoping: per-project-tagged
```

`per-project-tagged` 是默认 scoping，行为：

- 写入：所有项目的记忆进入同一共享 bank，并附带项目 tag。
- 项目 tag 命名：仓库主 checkout 根目录的 basename 小写（同一仓库的所有 worktree 归一到同一目录），如
  `~/code/nix-config` → `project:nix-config`。
- 检索：同时召回本项目 tag 的记忆与未标记的全局记忆。

其他 scoping 选项：`global`（单一共享 bank）、`per-project`（每项目独立 bank）。如需临时改检索预算/自动召回等，见 omp
`environment-variables.md` 的 `HINDSIGHT_*`（18 个覆盖项）或 `hindsight.*` 设置（如 `recallBudget`、
`retainEveryNTurns`、`autoRecall`、`autoRetain`）。

### 常用操作

| 操作               | 命令                                         |
| ------------------ | -------------------------------------------- |
| 查看注入的记忆内容 | omp 会话内 `/memory view`                    |
| 记忆统计 / 诊断    | `/memory stats` / `/memory diagnose`         |
| 立即触发保留       | `/memory enqueue`                            |
| 检索/存入/综合     | agent 工具的 `recall` / `retain` / `reflect` |
| 心智模型维护       | `/memory mm list`                            |

注意：`/memory clear` 只清本地会话状态与召回缓存，**不会删除服务端 bank**；删除 bank 需用 Hindsight
UI（:9999）或 API。

## 验证

```bash
curl -s http://localhost:8888/api/health   # 服务端就绪
curl -s http://localhost:8888/banks?limit=5 # 查看已建 bank（应出现项目 tag 相关 bank）
docker compose logs -f hindsight           # 容器日志（LLM 调用失败会在此可见）
```

omp 每会话首轮自动召回（`hindsight.autoRecall`），每 3 轮用户消息自动保留（`hindsight.retainEveryNTurns`）。

## 故障排查

- 容器起不来 / API 无响应：`docker compose logs`
  看启动错误；首次启动会做 embedding 维度探测与 LLM 连通性校验，DashScope 不通会卡在 initialize。
- LLM 4xx（如 400 model 不存在）：确认 `HINDSIGHT_API_LLM_MODEL=qwen3.8-flash` 与
  `~/.omp/agent/models.yml` 中 bailian provider 的模型 id 一致。
- `tool_choice ... does not support ... in thinking mode`（400，reflect/retain 重试）：模型思考模式与强制工具调用冲突，确认
  `HINDSIGHT_API_LLM_EXTRA_BODY` 含 `{"chat_template_kwargs": {"enable_thinking": false}}`
  后重建容器。
- dashscope 拒绝 `response_format` 时，可启用
  `HINDSIGHT_API_LLM_STRUCTURED_OUTPUT_FORCED_TOOL=true`（强制工具调用式结构化输出）。
- colima 拉镜像慢：`HTTPS_PROXY=http://127.0.0.1:7890 docker compose up -d` （colima
  VM 内拉取 ghcr.io 走本地代理）。

## 回滚

1. `docker-compose down` 停容器；数据卷 `hindsight-data` 保留（如需彻底清除：
   `docker volume rm hindsight-data`）。
2. 自启：注释/删除 `modules/darwin/hindsight.nix` 后重新 `just local`，launchd agent
   `hindsight-colima` / `hindsight-compose` 即被卸载。
3. omp 配置回滚：删除 `home/base/core/omp.nix` 中的 `memory`/`hindsight` 段（或 `memory.backend`
   改回 `off`），重新 switch 即恢复无记忆状态。
4. 移除 docker 工具链：删除 `modules/darwin/apps.nix` 中 `docker`/`colima`/`docker-compose`
   三个 systemPackages 条目并重新 switch。
