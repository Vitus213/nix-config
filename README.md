<h2 align="center">Vitus213 的 NixCoffee</h2>

<p align="center">
  <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/palette/macchiato.png" width="400" />
</p>

<p align="center">
  <a href="https://github.com/Vitus213/nix-config/stargazers">
    <img alt="Stargazers" src="https://img.shields.io/github/stars/Vitus213/nix-config?style=for-the-badge&logo=starship&color=C9CBFF&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://nixos.org/">
    <img src="https://img.shields.io/badge/NixOS-26.11-informational.svg?style=for-the-badge&logo=nixos&color=F2CDCD&logoColor=D9E0EE&labelColor=302D41">
  </a>
  <a href="https://github.com/Vitus213/nix-config">
    <img src="https://img.shields.io/badge/NixCoffee-Vitus213-informational.svg?style=for-the-badge&logo=nixos&color=F2CDCD&logoColor=D9E0EE&labelColor=302D41">
  </a>
</p>

这个仓库是我的个人 Nix 配置，用来维护 NixOS、nix-darwin 和 home-manager 环境。它包含个人硬件配置、`/persistent`
持久化布局、private `mysecrets` input 和 agenix secrets，不适合作为通用模板直接套到陌生机器上。

主机清单见 [hosts](./hosts)。密钥管理见 [secrets](./secrets)。全新 NixOS + preservation 部署流程见
[documents/fresh-nixos-preservation-deploy.md](./documents/fresh-nixos-preservation-deploy.md)。

## 仓库架构

| 路径               | 作用                                                                |
| ------------------ | ------------------------------------------------------------------- |
| `flake.nix`        | flake inputs、缓存配置和统一 outputs 入口                           |
| `flake.lock`       | 锁定 nixpkgs、home-manager、preservation、agenix、mysecrets 等输入  |
| `outputs/`         | 生成 `nixosConfigurations`、`darwinConfigurations`、packages 等输出 |
| `hosts/`           | 每台机器的系统入口、硬件配置、网络、preservation 和主机专用模块     |
| `modules/`         | 可复用的 NixOS / nix-darwin 系统级模块                              |
| `home/`            | 可复用的 home-manager 用户配置，区分 Linux、Darwin、TUI、GUI 层     |
| `secrets/`         | agenix 模块定义；密文本体来自 private `mysecrets` flake input       |
| `vars/`            | 用户名、网络等跨模块变量                                            |
| `overlays/`        | 局部 package overlay 和对应说明                                     |
| `hardening/`       | NixPak、bubblewrap、AppArmor 等沙箱和加固配置                       |
| `documents/`       | 中文配置文档、排障记录和主线变更记录                                |
| `nixos-installer/` | 旧版 ISO 安装辅助入口；当前新机部署优先看 fresh preservation 文档   |
| `infra/`           | homelab、对象存储、监控等基础设施配置说明                           |
| `templates/`       | 开发模板                                                            |
| `Justfile`         | 常用命令入口，例如 `just local`、`just test`、`just local-host ...` |

当前主要输出:

- NixOS 桌面: `apollo`、`athena`、`generic`
- macOS 桌面: `artemis`
- 独立 home-manager: `hermes`

`apollo` 是当前主力 NixOS 桌面。`athena` 是第二台 NixOS 桌面配置，仍处于规划/迁移状态。`generic`
是不启用个人 secrets 和 preservation 的通用桌面模板。`artemis` 是 nix-darwin 工作机。`hermes`
是 Ubuntu 上的独立 home-manager 配置。

当前关键输入和版本:

- 主 `nixpkgs`: `nixos-unstable`，当前求值版本 `26.11.20260702.6517942`
- `home-manager`: 跟随主 `nixpkgs`
- `preservation`: 管理 `/persistent` 持久化映射
- `agenix`: 管理 secrets 解密和 `/etc/agenix/*`
- `mysecrets`: private flake input，不在本仓库保存明文

## 新 NixOS 机器最快流程

新机器不要一上来执行 `just local`。`apollo`、`athena` 这类配置会把
`~/nix-config`、`~/.ssh`、`/etc/agenix` 等路径交给 preservation 管理；如果 `/persistent`
没准备好，或者 private secrets 没 rekey，第一次切换后很容易看到 `nix-config` 目录变空、`/etc/agenix`
创建失败、`/run/agenix.d/*.tmp` 不存在等问题。

最短成功路径:

1. 从 NixOS ISO 启动，分区、格式化并挂载 `/mnt`、`/mnt/boot`、`/mnt/persistent`。
2. 执行 `nixos-generate-config --root /mnt`，把当前机器的 `hardware-configuration.nix` 放进对应
   `hosts/olympians-<host>/`。
3. 如果新机器还不能访问 private `mysecrets`，首次安装先临时关闭 `modules.secrets.desktop.enable`。
4. 用 `nixos-install --root /mnt --flake .#<host>` 安装能启动的系统。
5. 重启前把 `/etc/machine-id` 和 SSH host keys 移到 `/mnt/persistent` 对应位置。
6. 第一次启动后生成 `/home/vitus/.ssh/id_ed25519`，把 public key 加入 private secrets
   recipients 并 rekey。
7. 确认 `~/nix-config/.git` 真实存在；如果 preservation 已经把 `~/nix-config`
   bind 到空目录，先把仓库内容复制进去。
8. 执行 `nix flake update mysecrets`，确认 `age.identityPaths` 指向 `/home/vitus/.ssh/id_ed25519`。
9. 以上都满足后，再执行 `just local debug` 或 `sudo nixos-rebuild switch --flake .#<host>`。

完整命令和排障见
[全新 NixOS 机器部署本仓库并启用 preservation](./documents/fresh-nixos-preservation-deploy.md)。

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

## 截图

![desktop](./_img/2026-01-05_niri-noctalia_desktop.webp)

![overview](./_img/2026-01-04_niri-noctalia_overview.webp)

![nvim](./_img/2026-01-04_niri-noctalia_nvim.webp)

## 部署

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

- [全新 NixOS + preservation 部署流程](./documents/fresh-nixos-preservation-deploy.md)
- [通用 NixOS 桌面 host](./documents/generic-nixos-host.md)
- [旧版 ISO 安装辅助入口](./nixos-installer/)
- [NixOS 内核策略](./documents/nixos-kernel.md)
- [rEFInd 启动配置](./documents/refind-boot.md)

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

## 学习资料

- [NixOS & Nix Flakes Book](https://github.com/ryan4yin/nixos-and-flakes-book)
- [nix-darwin-kickstarter](https://github.com/ryan4yin/nix-darwin-kickstarter)

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
