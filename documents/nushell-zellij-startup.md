# Nushell 与 Zellij 启动链路

本文记录当前 Nushell、fzf 和 Zellij 的启动关系，以及排查启动失败时的低风险验证方式。

## 当前版本

当前 `apollo` 配置求值出的相关版本：

| 组件    | 版本      | 来源                           |
| ------- | --------- | ------------------------------ |
| Nushell | `0.113.1` | 主 `nixpkgs` 的 `pkgs.nushell` |
| Zellij  | `0.44.3`  | 主 `nixpkgs` 的 `pkgs.zellij`  |
| fzf     | `0.73.1`  | 主 `nixpkgs` 的 `pkgs.fzf`     |

这些组件默认跟随主 `nixpkgs` 输入更新，不在仓库内单独固定版本。

## 配置入口

- `home/base/core/shells/default.nix`：启用 `programs.nushell`，并让 Home Manager 管理
  `~/.config/nushell/config.nu` 和 `env.nu`。
- `home/base/core/shells/config.nu`：仓库维护的基础 Nushell 配置。
- `home/base/core/core.nix`：启用 `programs.fzf`，Home Manager 会为 Nushell 生成 fzf 集成脚本。
- `home/base/tui/shell/default.nix`：加载 `nu_scripts` 中的别名、Kubernetes 辅助模块和 AI
  Agent 快捷命令。
- `home/base/tui/zellij/default.nix`：启用 Zellij，并在 Nushell 启动后自动进入 Zellij。

## 启动顺序

终端模拟器先启动 Nushell。Nushell 读取 Home Manager 生成的
`config.nu`，其中会依次加载基础配置、主题、主机 secret、Zellij 自动启动片段、共享 shell 片段、fzf 集成、direnv、atuin 和别名。

Zellij 自动启动依赖 Nushell 配置先成功解析。如果 Nushell 在解析 `config.nu` 或被 `source`
的脚本时失败，Zellij 不会进入，终端也会失去 Nushell 中定义的快捷命令。

## nu_scripts 导入约束

`nu_scripts` 的 `modules/argx` 导出了一个名为 `parse` 的自定义命令。不能使用：

```nu
use modules/argx *
```

星号导入会把 `argx` 的 `parse` 放入当前作用域，并覆盖 Nushell 内建的 `parse`。Home
Manager 生成的 fzf 集成脚本会调用内建 `parse --regex` 解析 SSH host。如果全局 `parse`
已被覆盖，就会出现：

```text
The `parse` command doesn't have flag `regex`.
```

当前配置使用限定名导入：

```nu
use modules/argx
```

这样 Kubernetes 模块仍可通过 `argx parse` 使用辅助解析器，同时全局 `parse` 保持为 Nushell 内建命令。

## 验证

检查当前版本：

```bash
nu --version
zellij --version
fzf --version
```

低风险验证 Home Manager 生成的 Nushell 配置可解析：

```bash
env ZELLIJ=1 INSIDE_EMACS=1 nu -c 'print "nushell config ok"'
```

验证 `argx parse` 仍通过限定名可用：

```bash
nu -c '"kubectl get pods" | argx parse | to nuon'
```

这里设置 `ZELLIJ=1` 和 `INSIDE_EMACS=1` 是为了跳过自动进入 Zellij，避免验证命令启动交互式会话。

## 回滚

如果后续 `nu_scripts` 移除 `argx parse` 的命名冲突，或仓库不再加载 Home Manager fzf
Nushell 集成，可以重新评估是否需要限定名导入。

当前不要回退到 `use modules/argx *`，否则会再次覆盖内建
`parse`，导致 fzf 集成和 Nushell 启动链路失败。
