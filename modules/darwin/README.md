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

Artemis 由主机模块在登录时启动现有 Colima profile，承载
`mks-redis`。Hindsight 服务由 Athena 提供。Artemis 的 Homebrew 仍应用声明的软件清单，部署时关闭自动更新和升级。`cleanup = "none"`
保留手工安装的应用。

## Artemis 的 FlClash

FlClash 0.9.4 使用上游 Apple Silicon DMG，安装到 `/Applications/Nix Apps/FlClash.app`。J1900 的
`新增订阅` 和 `SELOM` 地址由 agenix 解密到 `/run/agenix/flclash-subscriptions`，供 `vitus` 读取。

需要重新导入时，在 Artemis 运行以下命令，再在 FlClash 的「配置 → 添加 → 链接」切到批量模式并粘贴。

```bash
jq -er '.["新增订阅"], .SELOM' /run/agenix/flclash-subscriptions | /usr/bin/pbcopy
```

两份配置各自从原订阅地址更新。在 FlClash 中按需开启系统代理。系统回退用
`sudo -H /run/current-system/sw/bin/darwin-rebuild --rollback`，应用内已导入的配置可在「配置」页删除。

[FlClash 官方发布](https://github.com/chen08209/FlClash/releases/tag/v0.9.4)

更完整的 nix-darwin 说明见官方 [nix-darwin](https://github.com/nix-darwin/nix-darwin) 仓库和
[选项手册](https://nix-darwin.github.io/nix-darwin/manual/)。
