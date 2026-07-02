<h2 align="center">Ryan4Yin 的 Nix 配置</h2>

<p align="center">
  <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/palette/macchiato.png" width="400" />
</p>

<p align="center">
  <a href="https://github.com/ryan4yin/nix-config/stargazers">
    <img alt="Stargazers" src="https://img.shields.io/github/stars/ryan4yin/nix-config?style=for-the-badge&logo=starship&color=C9CBFF&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://nixos.org/">
    <img src="https://img.shields.io/badge/NixOS-25.11-informational.svg?style=for-the-badge&logo=nixos&color=F2CDCD&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://github.com/ryan4yin/nixos-and-flakes-book">
    <img src="https://img.shields.io/badge/Nix%20Flakes-learning-informational.svg?style=for-the-badge&logo=nixos&color=F2CDCD&logoColor=D9E0EE&labelColor=302D41">
  </a>
</p>

> 这套配置已经比较复杂，不适合刚接触 NixOS 的人直接照抄。如果你只是想学习 NixOS，可以先看
> [ryan4yin/nix-config/releases](https://github.com/ryan4yin/nix-config/releases) 里的早期版本，例如
> [i3-kickstarter](https://github.com/ryan4yin/nix-config/tree/i3-kickstarter)。

这个仓库用于构建和维护我的系统配置:

1. NixOS 桌面: NixOS、home-manager、niri、agenix 等
2. macOS 桌面: nix-darwin、home-manager，并复用一部分 Linux home-manager 配置
3. NixOS 服务器: Proxmox/KubeVirt 上的虚拟机，以及 Kubernetes、监控、存储等服务

主机清单见 [hosts](./hosts)。密钥管理见 [secrets](./secrets)。全新 NixOS + preservation 部署流程见
[documents/fresh-nixos-preservation-deploy.md](./documents/fresh-nixos-preservation-deploy.md)。

## 为什么使用 NixOS 和 Flakes

Nix 的核心价值是可复现、可回滚、可组合。系统配置、用户配置和部署入口都能以代码形式维护，配置一旦稳定，后续迁移和重装会轻很多。

Flakes 用来固定输入版本、组织多平台输出，并让 `nixos-rebuild`、`darwin-rebuild`、`home-manager`
都通过同一个仓库入口工作。

学习资料:

- [NixOS & Nix Flakes Book](https://github.com/ryan4yin/nixos-and-flakes-book)
- [nix-darwin-kickstarter](https://github.com/ryan4yin/nix-darwin-kickstarter)

## 组件

| 类别                       | 当前选择                                                                                       |
| -------------------------- | ---------------------------------------------------------------------------------------------- |
| 窗口管理器                 | [Niri][Niri]                                                                                   |
| 终端                       | [Zellij][Zellij] + [foot][foot] / [Kitty][Kitty] / [Alacritty][Alacritty] / [Ghostty][Ghostty] |
| 状态栏、通知、启动器、锁屏 | [noctalia-shell][noctalia-shell]                                                               |
| 登录管理器                 | [tuigreet][tuigreet]                                                                           |
| 配色                       | [catppuccin-nix][catppuccin-nix]                                                               |
| 网络管理                   | [NetworkManager][NetworkManager]                                                               |
| 输入法                     | [Fcitx5][Fcitx5] + [Rime][rime] + [雾凇拼音 Rime Ice][rime-ice]                                |
| 系统监控                   | [Btop][Btop]                                                                                   |
| 文件管理                   | [Yazi][Yazi] + [thunar][thunar]                                                                |
| Shell                      | [Nushell][Nushell] + [Starship][Starship]                                                      |
| 媒体播放器                 | [mpv][mpv]                                                                                     |
| 编辑器                     | [Neovim][Neovim] + VSCode / Cursor / Zed                                                       |
| 字体                       | [Nerd Fonts][Nerd fonts]                                                                       |
| 图片查看                   | [imv][imv]                                                                                     |
| 截图                       | Niri 内置截图                                                                                  |
| 录屏                       | [OBS][OBS]                                                                                     |
| 文件系统和加密             | tmpfs `/`、Btrfs 子卷、LUKS 加密、`/persistent` 持久化                                         |
| Secure Boot                | [lanzaboote][lanzaboote]                                                                       |

壁纸仓库: https://github.com/ryan4yin/wallpapers

## 截图

![desktop](./_img/2026-01-05_niri-noctalia_desktop.webp)

![overview](./_img/2026-01-04_niri-noctalia_overview.webp)

![nvim](./_img/2026-01-04_niri-noctalia_nvim.webp)

## 部署

> 不要直接把个人主机配置部署到陌生机器上。`apollo`、`athena` 等包含我的硬件配置、私有 secrets
> input 和个人路径。新机器如果只需要通用桌面，可先用 `generic`。

NixOS:

```bash
# 显式部署某个 NixOS 配置
sudo nixos-rebuild switch --flake .#apollo

# 通用桌面配置，不启用个人 secrets 和 preservation
sudo nixos-rebuild switch --flake .#generic

# 按当前 hostname 匹配 nixosConfigurations
just local

# 带更多构建和 trace 输出
just local debug
```

相关文档:

- [nixos-installer](./nixos-installer/): 旧版 ISO 安装流程
- [fresh-nixos-preservation-deploy.md](./documents/fresh-nixos-preservation-deploy.md): 全新 NixOS 机器启用 preservation 的当前流程
- [generic-nixos-host.md](./documents/generic-nixos-host.md): 不启用个人 secrets 和 preservation 的通用桌面 host

macOS:

```bash
# 首次部署前需要手动安装 Nix 和 Homebrew
nix-shell -p just nushell

# 按当前 hostname 部署默认 darwinConfiguration
just local

# 显式部署 Darwin 主机
just local-host artemis

# 带详细输出
just local debug
```

## 参考仓库

- [NixOS-CN/NixOS-CN-telegram](https://github.com/NixOS-CN/NixOS-CN-telegram)
- [notusknot/dotfiles-nix](https://github.com/notusknot/dotfiles-nix)
- [xddxdd/nixos-config](https://github.com/xddxdd/nixos-config)
- [bobbbay/dotfiles](https://github.com/bobbbay/dotfiles)
- [gytis-ivaskevicius/nixfiles](https://github.com/gytis-ivaskevicius/nixfiles)
- [davidtwco/veritas](https://github.com/davidtwco/veritas)
- [gvolpe/nix-config](https://github.com/gvolpe/nix-config)
- [Ruixi-rebirth/flakes](https://github.com/Ruixi-rebirth/flakes)
- [fufexan/dotfiles](https://github.com/fufexan/dotfiles)
- [nix-community/srvos](https://github.com/nix-community/srvos)
- [hlissner/dotfiles](https://github.com/hlissner/dotfiles)
- [viperML/dotfiles](https://github.com/viperML/dotfiles)
- [maxbrunet/dotfiles](https://github.com/maxbrunet/dotfiles)
- [1amSimp1e/dots](https://github.com/1amSimp1e/dots)

[Niri]: https://github.com/YaLTeR/niri
[Kitty]: https://github.com/kovidgoyal/kitty
[foot]: https://codeberg.org/dnkl/foot
[Alacritty]: https://github.com/alacritty/alacritty
[Ghostty]: https://github.com/ghostty-org/ghostty
[Nushell]: https://github.com/nushell/nushell
[Starship]: https://github.com/starship/starship
[Fcitx5]: https://github.com/fcitx/fcitx5
[rime]: https://wiki.archlinux.org/title/Rime
[rime-ice]: https://github.com/iDvel/rime-ice
[Btop]: https://github.com/aristocratos/btop
[mpv]: https://github.com/mpv-player/mpv
[Zellij]: https://github.com/zellij-org/zellij
[Neovim]: https://github.com/neovim/neovim
[imv]: https://sr.ht/~exec64/imv/
[OBS]: https://obsproject.com
[Nerd fonts]: https://github.com/ryanoasis/nerd-fonts
[catppuccin-nix]: https://github.com/catppuccin/nix
[NetworkManager]: https://wiki.gnome.org/Projects/NetworkManager
[tuigreet]: https://github.com/apognu/tuigreet
[thunar]: https://gitlab.xfce.org/xfce/thunar
[Yazi]: https://github.com/sxyazi/yazi
[Btrfs]: https://btrfs.readthedocs.io
[LUKS]: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
[lanzaboote]: https://github.com/nix-community/lanzaboote
[noctalia-shell]: https://github.com/noctalia-dev/noctalia-shell
