# hestia（NixOS-WSL 终端主机）

`hestia` 是运行在 Windows WSL 2 里的 NixOS 终端主机，不含桌面环境。入口：

- `outputs/x86_64-linux/src/hestia.nix`
- `hosts/hestia/default.nix`
- `hosts/hestia/home.nix`

## 当前行为

- 平台：NixOS 26.05（WSL），`flake.nix` 新增 `nixos-wsl` input
- 主机名 `hestia`；WSL 的瞬态主机名在重启 WSL（`wsl --shutdown`）后生效
- 默认用户 `vitus`（`wsl.defaultUser = "vitus"`），与仓库 vars 用户体系一致
- 系统包：`gcc gnumake git python3 nodejs`；启用 `nix-ld`
- home-manager 用户链：`home/linux/tui.nix`（纯终端，无 gui.nix）
- 保留 `bb` 服务：以 `vitus` 用户运行，目录 `/home/vitus/bb-app`，
  入口 `start.sh` 已改为 vitus 路径
- 不导入 `desktop.nix`，不使用 secrets / preservation / hardening

## WSL 特有调整

- `dconf.enable = false`：WSL 无桌面 D-Bus 会话，home-manager 的 dconf 激活必然失败
- `systemd.user.startServices = false`：无登录会话期间用户 systemd 未运行，
  HM 激活时不启动用户单元（如 `tldr-update.timer`），登录后会自动启动
- `nix.extraOptions` 引用 `/etc/agenix/nix-access-tokens`：该文件**不进仓库**，
  部署时手工写入 `access-tokens = github.com=...`；将来启用 agenix 后改由 secrets 管理
- 旧 WSL 配置的 `nixos` 用户在 `wsl.defaultUser` 切换到 `vitus` 时被移除，
  `bb-app`、`nix-config`、git 凭证均已从 `/home/nixos` 迁移到 `/home/vitus`

## my-secrets

- `my-secrets/secrets.nix` 新增 `hestia-wsl` recipient，对应当前 WSL 的
  `/home/vitus/.ssh/id_ed25519`（2026-09-13 生成，无口令，供 agenix 非交互解密）
- 用 `master_key` 解密后 rekey 了全部 5 个 `.age` 文件
- 验证：`agenix -d nix-access-tokens.age -i ~/.ssh/id_ed25519` 可正常解密


## omp + hindsight（AI 助手与记忆）

- `omp` 由 home-manager 安装（`/etc/profiles/per-user/vitus/bin/omp`），配置在 `~/.omp/agent/`
- provider：`bailian`（阿里云百炼兼容端点 `https://dashscope.aliyuncs.com/compatible-mode/v1`），
  apiKey 由 secrets 的 `bailian-key` 解密得到，models 含：
  - `deepseek-v4-flash-0731`（默认，`modelRoles.default`）
  - `deepseek-v4-pro-0813`、`glm-5.2-fast-preview`、`deepseek-v3.2`
- 注意：deepseek 系列是 reasoning 模型，maxTokens 太小会导致 content 为空（token 被思考吃掉）
- `hindsight`（vectorize-io/hindsight v0.9.2）作为 omp 记忆后端：
  - venv：`/home/vitus/hindsight/.venv`（uv 安装，含 torch CPU / pg0-embedded / 本地 embedding）
  - 数据：`~/.pg0/instances/hindsight`（内嵌 PostgreSQL 18 + pgvector），模型缓存 `~/.cache/huggingface`
  - systemd 服务：`hindsight.service`（declarative，见 `hosts/hestia/default.nix`），
    端口 127.0.0.1:8888
  - LLM 环境变量在 `/etc/hindsight.env`（**含 API key，不进仓库**；缺失时重跑
    `/home/vitus/hindsight/gen-env.sh` 生成）
  - omp 侧：`memory.backend=hindsight`、`hindsight.apiUrl=http://localhost:8888`
- NixOS 无 `/usr/share/zoneinfo`，pg0 需要它：`system.activationScripts.hindsightZoneinfo`
  每次 rebuild 自动重建该 symlink
- NixOS 跑 manylinux wheel（torch/pg0）缺系统库：`LD_LIBRARY_PATH` 指向
  zlib/xz/zstd/lz4/openssl/krb5/gcc-lib/readline 的 nix store 路径（写进 `/etc/hindsight.env`），
  对应包已加 GC root（`/nix/var/nix/gcroots/hindsight-libs`）防止被垃圾回收

## 常用命令（vitus@hestia）

```bash
omp -p "问题" --model bailian/deepseek-v4-flash-0731   # 对话（默认即该模型）
omp config list                                         # 查看配置
curl localhost:8888/health                              # hindsight 健康检查
systemctl status hindsight                              # 记忆服务状态

## 部署

```bash
cd ~/nix-config
sudo nixos-rebuild switch --flake .#hestia --accept-flake-config
```

注意：WSL 是容器化运行环境，没有系统引导；改动主机名、默认用户等与启动相关的配置后，
需要 `wsl --shutdown` 再重新进入 WSL 才会完全生效。

## 已知坑

- agenix 0.15（`4835b1dc`）传 `./file.age` 这类带 `./` 参数时，rules 解析会把前缀
  原样拼进 Nix 表达式，报 `There is no rule for ./xxx.age`；应传不带 `./` 的文件名。
  当前 `my-secrets/justfile` 的 `decrypt`/`edit` 命令存在该问题。
- `nixos-rebuild` 拉取私有 `mysecrets` input 需要认证：系统 nix.conf 通过
  `/etc/agenix/nix-access-tokens` 提供 `access-tokens = github.com=...`。
- ~/.gitconfig 由 home-manager 的 git 模块管理（激活时会删除），vitus 的 GitHub
  认证通过 `gh auth login --with-token` 写入 `~/.config/gh/hosts.yml` 生效。