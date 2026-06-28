# Linux 微信与 QQ

这份文档记录 NixOS 桌面上微信和 QQ 的当前安装方式、沙箱边界、验证和回滚方式。

## 当前结论

- 微信使用官方 Linux WeChat AppImage `4.1.1.4`，通过 `bwraps.wechat` 封装后安装。
- QQ 使用官方 Linux QQ `3.2.29-2026-05-28`，通过 `nixpaks.qq` 封装后安装。
- 本仓库没有更新整个 `nixpkgs-master` 输入；`nixpaks.qq` 只对 QQ 局部固定到远端 Nixpkgs
  master 当前来源，避免同时牵动 Cursor、VSCode、Rust、Guix、Clash Verge 等其它包。
- 两者都在 `home/linux/gui/base/misc.nix` 进入 Home Manager 用户包列表。
- 不把 Flatpak 作为主方案；Flatpak 只作为临时排障或对照方案。

## 配置入口

- `home/linux/gui/base/misc.nix`: 启用 `bwraps.wechat` 和 `nixpaks.qq`。
- `hardening/bwraps/wechat.nix`: 固定微信 AppImage 版本、下载源和 bubblewrap 参数。
- `hardening/nixpaks/qq.nix`: 基于局部固定后的 `pkgs-master.qq` 生成 QQ 的 Nixpak 封装。
- `hardening/nixpaks/default.nix`: 只对 `nixpaks.qq` 固定 QQ `3.2.29-2026-05-28` 源和 hash。

## 当前行为

微信:

- 版本为 `4.1.1.4`。
- 来源跟随 Nixpkgs master 的 Linux WeChat AppImage 源，使用 web archive 固定下载入口和 hash。
- 启动时把应用内的家目录隔离到 `~/Documents/WeChat_Data/home`。
- 聊天文件目录固定到 `~/Documents/WeChat_Data/xwechat_files`。
- 运行环境强制 `QT_QPA_PLATFORM=xcb`，并设置 `QT_IM_MODULE=fcitx`、`GTK_IM_MODULE=fcitx`。

QQ:

- 版本固定为 `3.2.29-2026-05-28`。
- 通过 Nixpak 运行，不直接裸跑 `pkgs.qq`。
- 可读写 Documents、Downloads、Music、Videos、Pictures 这些常用用户目录。
- 使用 Wayland 和 PipeWire socket，不启用 X11 socket。

## 为什么这样选

- Nixpkgs master 当前已经把 Linux WeChat 更新到 `4.1.1.4`，来源是腾讯官方 Linux AppImage。
- 2026-06-28 查询到远端 Nixpkgs master 的 Linux QQ 为
  `3.2.29-2026-05-28`，来源是腾讯 QQNT 官方 deb。
- 当前仓库锁定的 `pkgs-master.qq` 仍是
  `3.2.25-2026-02-05`，其官方下载地址已经返回 404；因此这里只对 QQ 局部固定到
  `3.2.29-2026-05-28`，不更新整个 `nixpkgs-master` 输入。
- Flathub 的 QQ manifest 也采用 `QQ_3.2.29_260528`，并显式配置 Wayland 输入法相关参数。
- Flathub 的 WeChat manifest 仍设置
  `QT_QPA_PLATFORM=xcb`，说明当前微信 Linux 客户端更适合按 X11/xcb 路径运行。
- 微信和 QQ 都是闭源 IM，应限制其默认读取整个家目录的能力；本仓库已有 Nixpak/bubblewrap 结构，比直接安装裸包更符合当前加固习惯。

参考:

- Nixpkgs WeChat: <https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/we/wechat/package.nix>
- Nixpkgs QQ: <https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/qq/qq/sources.nix>
- Flathub WeChat:
  <https://github.com/flathub/com.tencent.WeChat/blob/master/com.tencent.WeChat.yaml>
- Flathub QQ: <https://github.com/flathub/com.qq.QQ/blob/master/com.qq.QQ.yaml>

## 验证

低风险配置验证:

```bash
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.home.packages --show-trace
```

完整构建验证:

```bash
nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace
```

运行后检查:

- 微信能登录、收发文字和图片，文件保存到 `~/Documents/WeChat_Data`。
- QQ 能登录，在 Niri/Wayland 下显示窗口，Fcitx/Rime 能输入中文。
- Niri 窗口规则能把微信和 QQ 放到聊天工作区。

## 回滚

如果微信或 QQ 在当前版本不可用，先回滚安装入口:

- 在 `home/linux/gui/base/misc.nix` 注释掉 `bwraps.wechat`。
- 在 `home/linux/gui/base/misc.nix` 注释掉 `nixpaks.qq`。

然后重新构建 Home Manager/NixOS 配置。微信数据目录 `~/Documents/WeChat_Data`
不会因为注释包入口而自动删除。
