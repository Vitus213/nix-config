# 终端模拟器

当前终端模拟器只保留基础能力，标签页、复制、搜索、滚动历史和工作区主要交给 Zellij。

## 当前选择

- `kitty`: 主力终端
- `foot`: 轻量 Wayland 终端
- `alacritty`: 跨平台备用终端
- `ghostty`: 新终端方案，按平台启用

## `xterm-kitty` 远程主机问题

kitty 默认把 `TERM` 设置为 `xterm-kitty`。远程机器或 `sudo`
后的 root 环境如果没有对应 terminfo，就可能出现:

```text
'xterm-kitty': unknown terminal type
Error opening terminal: xterm-kitty.
```

优先解决方式:

```bash
kitten ssh user@host
```

如果不需要 kitty 的图形协议和扩展能力，可以临时改成通用 terminfo:

```bash
export TERM=xterm-256color
```

如果需要 kitty 能力，可以在远程机器安装或复制 terminfo:

```bash
sudo apt-get install kitty-terminfo
infocmp -a xterm-kitty | ssh myserver tic -x -o \~/.terminfo /dev/stdin
```

参考:

- <https://sw.kovidgoyal.net/kitty/faq/#i-get-errors-about-the-terminal-being-unknown-or-opening-the-terminal-failing-or-functional-keys-like-arrow-keys-don-t-work>
- <https://github.com/LnL7/nix-darwin/wiki/Terminfo-issues>
