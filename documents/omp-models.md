# omp 模型配置（models.yml）管理

本文档说明 `~/.omp/agent/models.yml` 的生成与管理机制。

## 架构

`models.yml` 是三部分合成的产物，由 nix-config 与 my-secrets 两个仓库协同管理：

| 位置                                          | 内容                                                                 | 是否含明文 key |
| --------------------------------------------- | -------------------------------------------------------------------- | -------------- |
| `nix-config/home/base/core/omp-models.yml.in` | 全部 provider / 模型定义，key 处为占位符（`@OPENAI_KEY@` 等）        | 否             |
| `my-secrets/omp-keys.age`                     | 6 个 API key 的 age 加密包（recipients 见 `my-secrets/secrets.nix`） | 否（密文）     |
| `~/.omp/agent/models.yml`                     | 上面两处合成后的实际配置（symlink → `.models.generated.yml`）        | 是（仅本机）   |

**生成链路：**

```
nix-config 模板(占位符) ──▶ Nix store（只读）
my-secrets/omp-keys.age ──agenix──▶ /run/agenix/omp-keys（本机解密）
        ↓ home.activation.ompModels（home/base/core/omp.nix）
~/.omp/agent/.models.generated.yml  ←─ symlink ── models.yml
```

## 使用方式

- **直接手改**：编辑 `~/.omp/agent/models.yml` 即时生效，无需
  `just local`。重建系统不会覆盖（B 模式）。
- **从模板重置**（覆盖手改）：运行 `omp-sync-models`。
- **把改动同步到全平台**：将手改增量合并回
  `home/base/core/omp-models.yml.in`，提交并推送 nix-config；其他机器更新 flake 后在本地运行
  `omp-sync-models`（首次生成）。

## 修改 key

1. 在 my-secrets 仓库更新明文并重新加密：`age -e -o omp-keys.age $(recipients) 明文文件`（recipients 取自
   `secrets.nix` 的 `systems`）。
2. 提交推送 my-secrets。
3. nix-config 更新 `mysecrets` flake input。
4. 目标机器重新解密（`darwin-rebuild switch` 触发 activate-agenix）后运行 `omp-sync-models`。

## 约束与注意事项

- **key 不进 Nix store**：模板只含占位符；含明文 key 的文件只存在于用户目录，勿提交到任何 git 仓库。
- **不要硬链接到 store**：omp 需要在其 agent 目录写锁；`models.yml.lock`
  为目录内独立文件，指向用户目录生成文件的软链接不受影响。
- 幂等保护：`home.activation.ompModels` 仅在 `models.yml` 缺失或非软链接时生成；已存在则跳过。

## 一键部署的 sudo 自动化（sudoers 白名单）

`darwin-rebuild switch`（`just local`）需要 root；为让 omp
agent 无需人工输密码即可部署，仅对这条命令开放免密（最小权限，其余 sudo 照旧要密码）：

1. **一次性安装规则**（在你的终端执行，需输一次 sudo 密码）：
   ```bash
   # bash / zsh
   echo 'vitus ALL=(ALL) NOPASSWD: /nix/store/*/bin/darwin-rebuild switch' | sudo tee /etc/sudoers.d/nix-darwin && sudo chmod 440 /etc/sudoers.d/nix-darwin
   ```
   ```nu
   # nushell（不支持 &&，分两行执行）
   echo 'vitus ALL=(ALL) NOPASSWD: /nix/store/*/bin/darwin-rebuild switch' | sudo tee /etc/sudoers.d/nix-darwin
   sudo chmod 440 /etc/sudoers.d/nix-darwin
   ```
2. 规则用 `/nix/store/*/bin/darwin-rebuild switch`
   通配任意 store 哈希（darwin-rebuild 每次重建路径哈希会变），且只匹配 `switch` 子命令。
3. 回滚：`sudo rm /etc/sudoers.d/nix-darwin`。

⚠️ 该规则只放行 darwin-rebuild 切换，不涉及其他特权操作。

## 配置入口

- `home/base/core/omp.nix`：activation 生成逻辑 + `omp-sync-models` 脚本
- `home/base/core/omp-models.yml.in`：模型模板
- `secrets/darwin.nix`：`age.secrets."omp-keys"` 声明（解密至 `/run/agenix/omp-keys`）
- `my-secrets/secrets.nix`：`"omp-keys.age".publicKeys`
