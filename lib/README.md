# 辅助函数库

这个目录提供 `flake.nix` 和 `outputs/`
使用的辅助函数，目标是减少重复代码，并让新增主机时的结构保持一致。

## 核心生成器

| 文件              | 用途                     |
| ----------------- | ------------------------ |
| `macosSystem.nix` | 生成 nix-darwin 系统配置 |
| `nixosSystem.nix` | 生成 NixOS 系统配置      |
| `default.nix`     | 汇总并导出所有 helper    |

## 支持的平台

- `x86_64-linux`: 主要 NixOS 桌面
- `aarch64-darwin`: Apple Silicon macOS 主机

## 使用原则

- 新增主机时优先复用这些生成器
- 不要在 `outputs/` 里重复实现系统生成逻辑
- 如果某个 helper 只服务单个主机，先放在主机目录里，确认有复用价值后再提升到 `lib/`
