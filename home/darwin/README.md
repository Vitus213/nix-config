# Darwin Home Manager 配置

这个目录存放 macOS 专用的 Home Manager 配置。

## 主要模块

- `default.nix`: Darwin home-manager 入口
- `shell.nix`: shell 环境和别名
- `terminal.nix`: 终端相关配置
- `rime-squirrel.nix`: Rime Squirrel 输入法配置
- `aerospace/`: AeroSpace 平铺窗口管理器配置

## 相关文档

- [AeroSpace 使用指南](../../documents/aerospace-usage.md)
- [modules/darwin](../../modules/darwin/README.md)

## 使用原则

- macOS 用户级配置放在这里
- 系统级 nix-darwin 配置放在 `modules/darwin/`
- 与 `artemis` 强绑定的配置放在 `hosts/darwin-artemis/`
- Bash/Zsh 只补 Homebrew 的 `/opt/homebrew/bin` 和
  `/usr/local/bin`；不再自动初始化未声明的 Conda，磁盘上的环境保留。
- Rime Squirrel 使用上游 `pkgs.rime-ice` 数据；独立 `default.custom.yaml` 引入
  `rime_ice_suggestion:/` 并保持小鹤双拼。数据目录与补丁均不使用 `force`，已有自定义由 Home
  Manager 标准备份机制保护（已有备份冲突时停止，不覆盖）。AeroSpace 保留 Tern 启动和工作区规则，删除未安装的 borders 启动命令；`resize`
  模式仍支持外部 `aerospace mode resize` 调用。
- Secret 直接使用 `/run/agenix`，删除无消费者的 `/etc/agenix/alias-for-work.nushell`
  过渡链接；只读用户 secret 权限为 `0400`。

本轮只修改声明与文档；Darwin 激活、终端交互和应用启动需在 macOS 验证，未执行系统切换或删除应用数据。
