# nix 自动垃圾回收（gc）策略

本仓库覆盖 NixOS 与 nix-darwin 双端，gc 策略在两端保持一致。

## 当前配置

| 端         | 入口                          | 行为                                                                                                                          |
| ---------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| NixOS      | `modules/nixos/base/nix.nix`  | 每周自动 gc，`--delete-older-than 7d`；`auto-optimise-store = true`                                                           |
| nix-darwin | `modules/darwin/nix-core.nix` | `launchd.user.agents."nix-gc"`：每周日 03:00 执行 `nix-collect-garbage --delete-older-than 7d`；`auto-optimise-store = false` |

两端统一：每周清理 7 天前的死路径，保留一周回滚窗口。

## 为什么 darwin 不用 nix.gc 模块

artemis 由 Determinate Nix 接管 daemon（`nix.enable = false`），而 nix-darwin 的 `nix.gc.automatic`
断言要求 `nix.enable`，且旧键 `nix.gc.dates` 已废弃（需 `nix.gc.interval`，仍需
`nix.enable`）。因此 darwin 侧用独立的 `launchd.user.agents."nix-gc"`
定时任务实现等效策略，rebuild 后由 launchd 注册生效。

## 为什么 darwin 关闭 auto-optimise-store

NixOS/nix#7273：并发 optimise 会产生

```
error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists
```

因此 darwin 侧不自动去重，改为需要时手动执行 `nix-store --optimise`。

## 手动操作

```bash
# 立即回收死路径（与自动策略一致，不动最近 7 天内容）
nix-collect-garbage --delete-older-than 7d

# 保留所有 generation 的更强清理（删全部未引用路径）
nix-store --gc

# 手动去重（darwin 上替代 auto-optimise-store）
nix-store --optimise
```

## 验证

- 定时任务：darwin 侧由 `launchd.user.agents."nix-gc"`
  注册（每周日 03:00），rebuild 后生效；NixOS 侧由 systemd timer 调度。
- 干跑：`nix store gc --dry-run`。
- 实测（2026-10-01，artemis）：手动执行 `nix-collect-garbage --delete-older-than 7d`
  删除 4579 个死路径，释放 14.5 GB， `/nix/store` 由 49G 降至 34G。
