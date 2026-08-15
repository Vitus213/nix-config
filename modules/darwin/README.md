# Darwin 系统模块

这个目录存放 nix-darwin 的系统级模块。

## 主要文件

- `default.nix`: Darwin 模块入口
- `apps.nix`: macOS 应用
- `nix-core.nix`: Nix 基础配置
- `security.nix`: 安全设置
- `ssh.nix`: SSH 配置
- `system.nix`: 系统设置
- `users.nix`: 用户设置
- darwin 不兼容包的移除 overlay 统一定义在 `lib/macosSystem.nix`

更完整的 nix-darwin 入门说明可参考
[nix-darwin-kickstarter](https://github.com/ryan4yin/nix-darwin-kickstarter)。
