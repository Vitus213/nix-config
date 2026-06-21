# Zellij

Zellij 是当前默认的终端工作区工具。它类似 tmux / screen，但交互提示更完整，适合作为统一的终端层。

## 为什么默认进入 Zellij

终端模拟器只负责显示字符，标签页、搜索、复制、滚动历史和 pane 管理交给 Zellij。这样可以在 kitty、foot、alacritty、ghostty 之间切换，而不丢失主要工作流。

Zellij 也适合远程服务器。熟悉一套快捷键后，本地和远程都能保持一致。

## Passthrough / Lock Mode

按 `Ctrl + g` 进入 lock mode 后，按键会直接发送给当前 pane 中的程序。

常见场景:

1. 本地 Zellij 里 SSH 到远程机器，远程也开了 Zellij
2. 当前程序和 Zellij 快捷键冲突，例如 Vim、tmux 或某些 TUI 程序
