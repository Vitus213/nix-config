# 终端模拟器

当前终端模拟器只保留基础能力，标签页、复制、搜索、滚动历史和工作区主要交给 Zellij。

## 当前选择

按平台保留两个终端：

- **Linux**:
  - `foot`: 主终端（`Mod+Return` 调
    `footclient`），Wayland 原生、启动快、内存低，server 模式常驻；`csd.preferred = none`
    不画标题栏；登录时 XDG autostart 只自动打开一个 foot 窗口
  - `alacritty`: 备用终端（`Mod+Shift+Return`），Rust 实现，不随登录自启
  - `kitty`: 图片粘贴终端（`Mod+Ctrl+Return`），见下节；里面不自动进 Zellij
- **macOS**:
  - `ghostty`: Homebrew cask 安装的终端
  - `alacritty`: 备用终端

已移除：Linux 上的 `ghostty`。

配置文件在 `terminals.nix`（foot + kitty + ghostty settings）与 `alacritty/default.nix`。

## kitty 与剪贴板图片粘贴

OMP 在 SSH 会话里直接粘贴本机剪贴板图片，只支持 kitty 的 OSC 5522 剪贴板读取协议（OMP
`utils/enhanced-paste.ts`）；foot 只有 OSC 52 文本剪贴板，传不了图片。herdr
client 内置同一协议的处理。使用方式：

1. `Mod+Ctrl+Return` 打开 kitty：Nushell 检测到 `KITTY_WINDOW_ID`，不会自动进 Zellij。
2. 直接 `ssh` 到目标主机跑 OMP，或运行 `herdr` 后在 pane 里跑 OMP。
3. 本机复制截图，在 OMP 输入框按粘贴：OMP 发出 OSC 5522 读取请求 → （herdr 转发）→
   kitty 弹授权确认，同意后图片进入会话。保持 kitty 默认 ask 授权，不自动放行。

链路不通或授权被拒绝时，OMP 会给出明确提示而不是假装贴图成功。

## `xterm-kitty` 远程主机问题

kitty 默认把 `TERM` 设置为 `xterm-kitty`，远程机器或 `sudo`
后的 root 环境如果没有对应 terminfo，就可能出现:

```text
'xterm-kitty': unknown terminal type
Error opening terminal: xterm-kitty.
```

athena 已在 `hosts/olympians-athena/default.nix` 通过 `environment.systemPackages` 补装
`pkgs.kitty.terminfo`（只要 terminfo 输出产物，不装 kitty
GUI），ssh 过去无需处理；其他远程主机按下面方式解决。

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
