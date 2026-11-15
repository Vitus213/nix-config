# Darwin 系统模块

这个目录存放 nix-darwin 的系统级模块。

## 主要文件

- `default.nix`: Darwin 模块入口
- `apps.nix`: macOS 应用
- `nix-core.nix`: Nix 基础配置
- `security.nix`: 安全设置
- `ssh.nix`: SSH 配置；[入站登录与系统默认文件恢复](../../documents/darwin-ssh.md)
- `system.nix`: 系统设置
- `users.nix`: 用户设置
- Darwin 使用真实 nixpkgs 包，不再以 `emptyDirectory`
  替换不兼容包，也不覆盖 direnv 构建；共享 overlays 仍按原机制追加。`ncdu`
  使用上游包，GDB 在编辑器调用方限定为 Linux。

`nix.enable = false` 保留给外部安装管理的 Nix daemon（artemis 当前为 Lix）；无效的 `nix.settings` /
`nix.extraOptions` 已移除，每周自定义 launchd
GC 保留。访问 token 的 daemon 配置需要由外部安装管理，仓库不再宣称 nix-darwin 会写入它。

Hindsight 的旧 Darwin launchd /
Compose 定义和专用 Docker、Colima 工具声明已退役；当前服务在 athena。此次配置清理不停止运行中的旧容器，也不删除 Colima、Docker 卷或用户凭据。Homebrew
`cleanup = "none"` 保留手工安装应用。

更完整的 nix-darwin 说明见官方 [nix-darwin](https://github.com/nix-darwin/nix-darwin) 仓库和
[选项手册](https://nix-darwin.github.io/nix-darwin/manual/)。
