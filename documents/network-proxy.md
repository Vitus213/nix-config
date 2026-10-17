# 网络与代理策略

本文记录 artemis（macOS）当前的网络出网模型与配置约束。2026-10-17 起本地代理（FlClash）已下线，出网统一由软路由透明代理承担。

## 当前模型

- 出网路径：软路由透明代理，终端与容器**直连即可**（实测 `https://www.gstatic.com/generate_204`
  直连返回 204）。
- IPv6：软路由侧已关闭，本机应用不得依赖 IPv6 出网。
- 本地代理进程：无。FlClash（mixed-port `127.0.0.1:7890`）已停用，不再随系统启动。

## 硬性约束

1. **任何网络设置相关的变更必须先与用户同步**，经确认后再落地。
2. 不得引入指向 `127.0.0.1:7890` / `host.docker.internal:7890`
   的代理配置（brew 环境、proxychains、`.env` 文件、docker 容器环境等）。
3. `~/.docker/config.json` 不配置 `proxies`
   段——它会静默给所有新建容器注入代理环境变量，代理失效时容器会 crash loop（hindsight 曾因此挂掉，见
   [Hindsight 记忆后端](./hindsight.md) 故障排查）。
4. brew 走 nju 镜像直连（`modules/darwin/apps.nix` 的 `homebrew_mirror_env`），不叠加代理 env。

## 历史遗留清理记录（2026-10-17）

- 删除 `home/darwin/proxy/`（proxychains 配置与 symlink）。
- `modules/darwin/apps.nix` 移除注入 brew 激活环境的 `HTTP(S)_PROXY=127.0.0.1:7890`。
- 删除 `scripts/darwin_set_proxy.py`（向 nix daemon plist 注入 `192.168.5.101:7890`
  的旧脚本，该地址已不在当前网段）。
- `~/.docker/config.json` 移除 `proxies.default` 段，并 `--force-recreate` 重建 hindsight 容器。
- `~/work/shopping-console/.env.local` 删除 `HTTP(S)_PROXY` 行。

## 排查速查

```bash
curl -sS -o /dev/null -w '%{http_code}\n' https://www.gstatic.com/generate_204  # 出网是否正常（期望 204）
env | grep -i proxy                         # 会话内是否残留代理变量（应无）
docker inspect <容器> --format '{{json .Config.Env}}' | grep -i proxy  # 容器是否被注入代理（应无）
scutil --proxy                               # 系统代理（应全 0）
```

若外网不通：先区分「直连故障」与「残留代理配置」——后者会表现为 connection refused / Unable to
connect，且 `env` 或容器 Env 里能看到 `7890` 字样。
