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

**快速导航**：[主机清单](./hosts) · [密钥管理](./secrets) · [文档索引](./documents/README.md) ·
[变更记录](./documents/changelog.md) · [新机部署](./documents/fresh-nixos-preservation-deploy.md)

## 仓库架构

| 路径               | 作用                                                                                   |
| ------------------ | -------------------------------------------------------------------------------------- |
| `flake.nix`        | flake inputs、二进制缓存配置；`outputs` 直接转交给 `outputs/`                          |
| `flake.lock`       | 锁定 nixpkgs、home-manager、preservation、agenix、mysecrets 等输入                     |
| `outputs/`         | 按平台生成 `nixosConfigurations`、`darwinConfigurations`、eval tests 等输出            |
| `lib/`             | `nixosSystem` / `macosSystem` 生成器和 `scanPaths`、`relativeToRoot` 等工具            |
| `hosts/`           | 每台机器的系统入口、硬件配置、网络、preservation 和主机专用模块                        |
| `modules/`         | 可复用的 NixOS / nix-darwin **系统级**模块                                             |
| `home/`            | 可复用的 home-manager **用户级**配置，分 `base`（共享）/ `linux` / `darwin`            |
| `secrets/`         | agenix 模块定义；密文本体来自 private `mysecrets` flake input                          |
| `vars/`            | 用户名、网络地址等跨模块变量（以 `myvars` 注入所有模块）                               |
| `overlays/`        | 局部 package overlay，每个子目录自带 README 说明原因和移除条件                         |
| `hardening/`       | NixPak、bubblewrap、AppArmor 等沙箱和加固配置                                          |
| `documents/`       | **唯一的文档目录**：专题文档、排障记录、变更记录，入口是 [索引](./documents/README.md) |
| `nixos-installer/` | 旧版 ISO 安装辅助入口；新机部署优先看 fresh preservation 文档                          |
| `infra/`           | homelab 对象存储（MinIO / Loki）的 Terraform 配置                                      |
| `certs/`           | 自用私有 CA 的公开证书和生成脚本                                                       |
| `templates/`       | `nix flake init` 开发模板                                                              |
| `scripts/`         | 仓库自检脚本，例如禁止引入 stable/master nixpkgs 的策略检查                            |
| `Justfile`         | 常用命令入口，例如 `just local`、`just test`、`just local-host ...`                    |
| `AGENTS.md`        | 自动化代理（和人）在本仓库工作时的约定：验证方式、文档同步、changelog 规则             |

### 一台主机是怎么拼出来的

```text
flake.nix
  └─ outputs/default.nix            注入 mylib / myvars / 全部 inputs（specialArgs）
       └─ outputs/<system>/default.nix   haumea 自动加载 src/ 下每个主机文件
            └─ outputs/<system>/src/<host>.nix
                 ├─ nixos-modules : secrets/*.nix + modules/nixos/desktop.nix + hosts/<host>/
                 └─ home-modules  : home/linux/gui.nix（或 tui.nix）+ hosts/<host>/home.nix
                      └─ lib/nixosSystem.nix 组装成 nixosConfigurations.<host>
```

`modules/` 和 `home/` 下的聚合目录（如
`modules/nixos/desktop/`、`home/base/tui/`、`home/linux/gui/base/`）的 `default.nix` 使用
`mylib.scanPaths ./.`：**在这些目录里新增的 `.nix`
文件和子目录会被自动导入**，不需要手动登记；删除文件即取消导入。 `hosts/` 和 `outputs/`
则是显式列出导入。

### 想改某样东西，去哪里

| 想改的东西                          | 位置                                                                 |
| ----------------------------------- | -------------------------------------------------------------------- |
| 只影响某一台机器                    | `hosts/<host>/default.nix`（系统）或 `hosts/<host>/home.nix`（用户） |
| 所有 Linux 桌面的系统服务           | `modules/nixos/desktop/`                                             |
| 所有 NixOS 机器的基础设置           | `modules/nixos/base/`                                                |
| NixOS 和 macOS 共享的系统设置       | `modules/base/`                                                      |
| shell、git、编辑器等终端工具        | `home/base/core/`、`home/base/tui/`                                  |
| Niri、Noctalia、输入法等 Linux GUI  | `home/linux/gui/`                                                    |
| AeroSpace、Squirrel 等 macOS 用户层 | `home/darwin/`                                                       |
| 新增或修改一个 secret               | `secrets/*.nix` + private `mysecrets` 仓库，见 [secrets](./secrets)  |
| IP、网关、SSH 别名                  | `vars/networking.nix`                                                |
| 给某个包打补丁 / 换版本             | `overlays/<pkg>/`                                                    |

当前主要输出:

- NixOS 桌面: `apollo`、`athena`、`generic`
- NixOS-WSL 终端: `hestia`
- macOS 桌面: `artemis`
- 独立 home-manager: `hermes`

`apollo` 是当前主力 NixOS 桌面。`athena` 是第二台 NixOS 桌面配置，仍处于规划/迁移状态。`generic`
是不启用个人 secrets 和 preservation 的通用桌面模板。`hestia` 是 Windows
WSL 里的无桌面 NixOS。`artemis` 是自用的 MacBook Air M1（nix-darwin）。`hermes`
是 Ubuntu 上的独立 home-manager 配置。

当前关键输入和版本:

- 主 `nixpkgs`: `nixos-unstable`；macOS 使用 `nixpkgs-unstable`
- `home-manager`: `master`，跟随主 `nixpkgs`
- `preservation`: 管理 `/persistent` 持久化映射
- `agenix`: 管理 secrets 解密和 `/etc/agenix/*`
- `mysecrets`: private flake input，不在本仓库保存明文

更新频繁的 AI Agent CLI（omp、bb 等）不走 flake input，而是用户级 bun /
npm 全局安装，与系统更新解耦，见
[Nushell AI Agent 快捷命令](./documents/nushell-ai-agent-aliases.md)。

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
| 文件管理                   | [Yazi][Yazi] + [Dolphin][dolphin]                                                              |
| Shell                      | [Nushell][Nushell] + [Starship][Starship]                                                      |
| 媒体播放器                 | [mpv][mpv]                                                                                     |
| 编辑器                     | [Neovim][Neovim] + VSCode / Cursor / Zed                                                       |
| 字体                       | [Nerd Fonts][Nerd fonts]                                                                       |
| 图片查看                   | [imv][imv]                                                                                     |
| 截图                       | Niri 内置截图                                                                                  |
| 录屏                       | [OBS][OBS]                                                                                     |
| 文件系统和加密             | tmpfs `/`、Btrfs 子卷、LUKS 加密、`/persistent` 持久化                                         |
| Secure Boot                | 当前未启用（历史方案为 [lanzaboote][lanzaboote]，已随主机清理移除）                            |

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

相关文档（全部专题见 [文档索引](./documents/README.md)）:

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
[dolphin]: https://apps.kde.org/dolphin/
[Yazi]: https://github.com/sxyazi/yazi
[Btrfs]: https://btrfs.readthedocs.io
[LUKS]: https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
[lanzaboote]: https://github.com/nix-community/lanzaboote
[noctalia-shell]: https://github.com/noctalia-dev/noctalia-shell
