# 终端模拟器

当前终端模拟器只保留基础能力，标签页、复制、搜索、滚动历史和工作区主要交给 Zellij。

## 当前选择

按平台保留两个终端：

- **Linux**:
  - `foot`: 主终端（`Mod+Return`），Wayland 原生、启动快、内存低，server 模式常驻
  - `alacritty`: 备用终端（`Mod+Shift+Return`），Rust 实现
- **macOS**:
  - `ghostty`: Homebrew cask 安装的终端
  - `alacritty`: 备用终端

已移除：Linux 上的 `ghostty`、所有平台的 `kitty`（零使用）。

配置文件在 `terminals.nix`（foot + ghostty settings）与 `alacritty/default.nix`。

## 历史参考：`xterm-kitty` 远程主机问题

kitty 已从本机移除。如果未来在远程主机上使用 kitty，它默认把 `TERM` 设置为 `xterm-kitty`，远程机器或
`sudo` 后的 root 环境如果没有对应 terminfo，就可能出现:

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
