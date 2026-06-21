# Darwin Home Manager 配置

这个目录存放 macOS 专用的 Home Manager 配置。

## 主要模块

- `default.nix`: Darwin home-manager 入口
- `shell.nix`: shell 环境和别名
- `terminal.nix`: 终端相关配置
- `rime-squirrel.nix`: Rime Squirrel 输入法配置
- `aerospace/`: AeroSpace 平铺窗口管理器配置
- `proxy/`: 代理和 proxychains 配置

## 相关文档

- [AeroSpace 使用指南](../../documents/aerospace-usage.md)
- [modules/darwin](../../modules/darwin/README.md)

## 使用原则

- macOS 用户级配置放在这里
- 系统级 nix-darwin 配置放在 `modules/darwin/`
- 与 `artemis` 强绑定的配置放在 `hosts/darwin-artemis/`
