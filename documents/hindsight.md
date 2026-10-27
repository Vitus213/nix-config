# Hindsight Agent 记忆后端

本文记录 Hindsight（agent 长期记忆服务）的部署方式、LLM 配置，以及它作为 omp memory
backend 的接入与使用。2026-10 起服务端常驻 **athena**（NixOS 容器服务），此前跑在
artemis（macOS colima）。

## 概述

[Hindsight](https://hindsight.vectorize.io/) 是开源 agent 记忆系统（PostgreSQL 存储），提供
`retain`（存入）/ `recall`（检索）/ `reflect`（综合问答）三类操作。omp 原生支持
`memory.backend: hindsight`，各机器的 omp 通过局域网 HTTP 访问 athena 上的服务端。

## 部署架构

```
┌──────────────────── athena（NixOS，192.168.100.11）────────────────────┐
│  oci-containers（podman 后端，hosts/olympians-athena/hindsight.nix）   │
│   └─ hindsight 容器（ghcr.io/vectorize-io/hindsight:latest）           │
│        ├─ REST API  :8888   ← 局域网 omp memory backend               │
│        ├─ Web UI    :9999                                              │
│        └─ 嵌入式 PostgreSQL（pg0）→ podman 卷 hindsight-data           │
│  LLM key：/var/lib/hindsight/hindsight.env（0600，bootstrap 自 agenix）│
└────────────────────────────────────────────────────────────────────────┘
        ▲                    ▲
   apollo（omp）          artemis（omp）
   http://athena:8888    http://athena:8888
```

- 服务定义：`hosts/olympians-athena/hindsight.nix`（`hosts/olympians-athena/default.nix`
  导入）；容器后端 podman 由 `modules/nixos/desktop/virtualisation.nix` 统一提供。
- 端口：8888（API）、9999（UI）已在 `networking.firewall.allowedTCPPorts` 声明（防火墙
  当前默认关闭，先声明将来打开不用补）。
- 数据持久化：podman 卷 `hindsight-data` 挂载容器内 `/home/hindsight/.pg0`。注意 athena
  的 podman `autoPrune --all` 每周清理未被引用的资源——**卷被容器引用即安全**；导入数据
  前先确保容器已创建并停机（见迁移一节）。

## LLM 与 Embedding 配置

| 项                           | 值                                     | 说明                                                                                                          |
| ---------------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `HINDSIGHT_API_LLM_PROVIDER` | `openai`                               | OpenAI 兼容协议                                                                                               |
| `HINDSIGHT_API_LLM_BASE_URL` | `https://sub.scitrace.cc/v1`           | scitrace relay OpenAI 兼容中转（2026-10-17 起；bailian/DashScope 两把 key 均已吊销）                          |
| `HINDSIGHT_API_LLM_MODEL`    | `gemini-3.1-flash-lite`                | 与 omp `~/.omp/agent/models.yml` 的 gemini provider 同款；切换当日 relay 上 gpt 系 502/503，gemini 系实测 200 |
| `HINDSIGHT_API_LLM_API_KEY`  | `/var/lib/hindsight/hindsight.env`     | 0600 文件；由服务 `preStart` 从 `/run/agenix/omp-keys` 的 `gemini:` 行自动 bootstrap，不进 Nix store          |
| Embeddings                   | 默认 `local`                           | 镜像内建 ONNX 本地模型（BAAI/bge-small-en-v1.5），无外部 embedding API 依赖                                   |

key bootstrap 逻辑：文件不存在或为空时，`preStart` 提取 omp-keys 的 `gemini:` 行写入
`HINDSIGHT_API_LLM_API_KEY=...`；omp-keys 缺 gemini 行则写空文件让容器照常启动（LLM 操作
降级，下次重启重试）。**gemini key 轮换后需删除该文件并重启服务**重新提取。

## 启动、停止与自启

服务生命周期由 NixOS 声明，`nixos-rebuild switch` 后 `hindsight.service` 随系统自启：

```bash
systemctl status hindsight        # 状态
sudo systemctl stop hindsight     # 停止（数据卷保留）
sudo podman logs -f hindsight     # 容器日志（LLM 调用失败在此可见）
sudo podman ps                    # 容器列表（athena 的 docker 命令是 podman 兼容别名）
```

## omp 集成（per-project-tagged）

各机器用户级 `~/.omp/agent/config.yml`（手工维护的本机文件）：

```yaml
memory:
  backend: hindsight
hindsight:
  apiUrl: http://athena:8888
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
UI（`http://athena:9999`）或 API。

## 从 artemis 迁移数据（已定流程，供复查/回退）

artemis（macOS colima）上的旧实例数据在 docker 卷 `hindsight-data`。迁移顺序：

1. **停 artemis 侧写入**：卸载 launchd 的 `hindsight-compose` agent（其 300s 兜底会重新
   `docker-compose up -d`），再 `cd modules/darwin && docker-compose -p hindsight -f hindsight-compose.yml stop`。
2. **导出卷**（容器停机后 tar，避免 PG 数据不一致）：
   ```bash
   docker run --rm -v hindsight-data:/data -v /tmp:/backup alpine \
     tar czf /tmp/hindsight-data.tgz -C /data .
   ```
3. **传输**：`scp /tmp/hindsight-data.tgz athena:/tmp/`。
4. **athena 导入**（容器已由 rebuild 创建并停机）：
   ```bash
   sudo podman run --rm -v hindsight-data:/data -v /tmp:/backup:ro alpine \
     sh -c 'tar xzf /tmp/backup/hindsight-data.tgz -C /data'
   sudo systemctl start hindsight
   ```
5. **切换客户端**：apollo / artemis 的 `~/.omp/agent/config.yml` 把 `hindsight.apiUrl` 改为
   `http://athena:8888`，重开 omp 会话。
6. **artemis 退役**：删除/注释 `modules/darwin/hindsight.nix` 与 `apps.nix` 的容器工具链后
   `just local`；旧容器与 `hindsight-data` 卷保留观察一段时间后再清理。

## 验证

```bash
curl -s http://athena:8888/api/health   # 服务端就绪
curl -s http://athena:8888/banks?limit=5 # 查看已建 bank（应出现项目 tag 相关 bank）
ssh athena -- sudo podman logs hindsight
```

omp 每会话首轮自动召回（`hindsight.autoRecall`），每 3 轮用户消息自动保留（`hindsight.retainEveryNTurns`）。

## 故障排查

- 容器起不来 / API 无响应：`ssh athena -- sudo podman logs hindsight`
  看启动错误；首次启动会做 embedding 维度探测与 LLM 连通性校验，relay 不通会记 4xx/5xx 但服务仍启动（LLM 相关操作降级）。
- LLM 4xx（如 400 model 不存在）：确认 `HINDSIGHT_API_LLM_MODEL` 是 relay 当前可用模型（以 omp
  `~/.omp/agent/models.yml` 各 provider 列表为准），改 `hindsight.nix` 的 environment 后 rebuild。
- key 丢失 / 401：检查 `/var/lib/hindsight/hindsight.env` 是否非空；`/run/agenix/omp-keys`
  是否已解密（`modules.secrets.desktop.enable`）。修正后删除 env 文件并重启服务重新 bootstrap。
- 中转模型拒绝 `response_format` 时，可在 `hindsight.nix` 的 environment 加
  `HINDSIGHT_API_LLM_STRUCTURED_OUTPUT_FORCED_TOOL = "true";`（强制工具调用式结构化输出）。
- 拉镜像慢/失败：athena 经软路由透明代理直连 ghcr.io 即可（历史 FlClash / 镜像站方案均已废弃）。
- 卷被误清（`podman volume ls` 无 hindsight-data）：autoPrune 只清未引用资源，容器存在即不会
  发生；若被手动删除，按上文迁移一节从 artemis 备份重新导入。

## 回滚

1. athena 侧：`sudo systemctl stop hindsight`（数据卷保留；彻底清除
   `sudo podman volume rm hindsight-data`）。
2. 从 nix 移除：删除 `hosts/olympians-athena/hindsight.nix` 及 `default.nix` 的 import 后 rebuild。
3. artemis 回退：重新启用 `modules/darwin/hindsight.nix` 并 `just local`，omp `apiUrl` 改回
   `http://localhost:8888`（旧卷未删时数据仍在）。
4. omp 配置回滚：编辑用户级 `~/.omp/agent/config.yml`，删除 `memory`/`hindsight` 段（或
   `memory.backend` 改回 `off`）即恢复无记忆状态。

## 相关文件

- `hosts/olympians-athena/hindsight.nix`：容器服务 + key bootstrap + 端口声明
- `hosts/olympians-athena/default.nix`：import 上者
- `modules/nixos/desktop/virtualisation.nix`：podman 后端（全桌面主机共用）
- `modules/darwin/hindsight.nix`：artemis 旧部署（待退役后删除）
