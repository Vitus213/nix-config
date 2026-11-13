# Zellij

Zellij 是终端工作区工具，提供标签页、搜索、复制、滚动历史和 pane 管理。

## 启动方式

Linux 默认终端为 kitty，直接进入 Nushell，需要 Zellij 时手动运行 `zj` 或
`zellij`。非 kitty 的普通交互式 Nushell 保留自动启动；Zellij、Emacs 和 Herdr Pane 内跳过，避免嵌套。

Zellij 也适合远程服务器。熟悉一套快捷键后，本地和远程都能保持一致。

## Passthrough / Lock Mode

按 `Ctrl + g` 进入 lock mode 后，按键会直接发送给当前 pane 中的程序。

常见场景:

1. 本地 Zellij 里 SSH 到远程机器，远程也开了 Zellij
2. 当前程序和 Zellij 快捷键冲突，例如 Vim、tmux 或某些 TUI 程序
