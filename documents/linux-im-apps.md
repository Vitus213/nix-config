# Linux 微信与 QQ

这份文档记录 NixOS 桌面上微信和 QQ 的当前安装方式、沙箱边界、验证和回滚方式。

## 当前结论

- 微信使用官方 Linux WeChat AppImage `4.1.1.4`，通过 `bwraps.wechat` 封装后安装。
- QQ 使用官方 Linux QQ `3.2.29-2026-05-28`，通过 `nixpaks.qq` 封装后安装。
- QQ 的封装从主 `nixpkgs` 的 `pkgs.qq` 派生，并在 `hardening/nixpaks/default.nix`
  中局部固定官方 deb 的 URL 和 hash。
- 两者都在 `home/linux/gui/base/misc.nix` 进入 Home Manager 用户包列表。
- Linux GUI 会话默认自启动微信，不再默认自启动 Telegram；两者仍保留在用户包中。
- 不把 Flatpak 作为主方案；Flatpak 只作为临时排障或对照方案。

## 配置入口

- `home/linux/gui/base/misc.nix`: 启用 `bwraps.wechat` 和 `nixpaks.qq`。
- `home/linux/gui/base/xdg/autostart.nix`: 将微信桌面条目加入 XDG
  autostart，并移除 Telegram 自启动条目。
- `home/linux/gui/base/fcitx5/default.nix`: 禁用系统 Fcitx5 XDG autostart，只保留 Home
  Manager 服务。
- `hardening/bwraps/wechat.nix`: 固定微信 AppImage 版本、下载源和 bubblewrap 参数。
- `hardening/nixpaks/qq.nix`: 基于局部固定后的 `pkgs.qq` 生成 QQ 的 Nixpak 封装。
- `hardening/nixpaks/default.nix`: 只对 `nixpaks.qq` 固定 QQ `3.2.29-2026-05-28` 源和 hash。

## 当前行为

微信:

- 版本为 `4.1.1.4`。
- 来源跟随 Nixpkgs master 的 Linux WeChat AppImage 源，使用 web archive 固定下载入口和 hash。
- 启动时把应用内的家目录隔离到 `~/Documents/WeChat_Data/home`。
- 聊天文件目录固定到 `~/Documents/WeChat_Data/xwechat_files`。
- 运行环境强制 `QT_QPA_PLATFORM=xcb`，并设置 `QT_IM_MODULE=fcitx`、`GTK_IM_MODULE=fcitx`。
- XDG autostart 使用封装包提供的 `wechat.desktop`，登录桌面会话后自动启动微信。
- 沙箱内移除 `WAYLAND_DISPLAY`，显式设置 `XMODIFIERS=@im=fcitx`，并保留 `QT_QPA_PLATFORM=xcb`、
  `QT_IM_MODULE=fcitx` 和 `GTK_IM_MODULE=fcitx`，让新版微信通过 XWayland/XIM 显示 Fcitx5 候选框。
- Fcitx5 只由 `fcitx5-daemon.service` 启动，并在 XWayland 就绪后注册 `XIM_SERVERS`。

QQ:

- 版本固定为 `3.2.29-2026-05-28`。
- 通过 Nixpak 运行，不直接裸跑 `pkgs.qq`。
- 可读写 Documents、Downloads、Music、Videos、Pictures 这些常用用户目录。
- 使用 Wayland 和 PipeWire socket，不启用 X11 socket。

## 为什么这样选

- Nixpkgs 已经包含 Linux WeChat `4.1.1.4`，来源是腾讯官方 Linux AppImage。
- 当前 QQ 固定到
  `3.2.29-2026-05-28`，来源是腾讯 QQNT 官方 deb；固定 URL 和 hash 是为了避免上游下载地址变动导致旧 Nixpkgs 版本的
  `pkgs.qq` 失效。
- Flathub 的 QQ manifest 也采用 `QQ_3.2.29_260528`，并显式配置 Wayland 输入法相关参数。
- Flathub 的 WeChat manifest 仍设置
  `QT_QPA_PLATFORM=xcb`，说明当前微信 Linux 客户端更适合按 X11/xcb 路径运行。
- 微信和 QQ 都是闭源 IM，应限制其默认读取整个家目录的能力；本仓库已有 Nixpak/bubblewrap 结构，比直接安装裸包更符合当前加固习惯。
- WeChat `4.1.1.4` 同时看到 Wayland 和 X11 环境时可能改走 Fcitx
  Portal；该路径的候选框坐标在 Niri/XWayland 下可能落到屏幕外。更关键的是，系统 XDG
  autostart 与 Home
  Manager 服务曾同时启动 Fcitx5：前者过早启动且未注册 XIM，后者因 D-Bus 名称被占用而退出。当前禁用系统 autostart，只保留 Home
  Manager 服务，并在微信沙箱中隐藏 Wayland、强制 XIM。

参考:

- Nixpkgs WeChat:
  <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/we/wechat/package.nix>
- Nixpkgs QQ: <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/qq/qq/sources.nix>
- Flathub WeChat:
  <https://github.com/flathub/com.tencent.WeChat/blob/master/com.tencent.WeChat.yaml>
- Flathub QQ: <https://github.com/flathub/com.qq.QQ/blob/master/com.qq.QQ.yaml>

## 验证

低风险配置验证:

```bash
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.home.packages --show-trace
nix eval --json --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in flake.nixosConfigurations.apollo.config.home-manager.users.vitus.xdg.autostart.entries' --impure
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in flake.nixosConfigurations.apollo.config.home-manager.users.vitus.xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text' --impure
```

完整构建验证：

```bash
nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace
nix build .#nixosConfigurations.athena.config.system.build.toplevel --no-link --show-trace
```

运行时确认 Fcitx5 服务与 XIM：

```bash
systemctl --user is-active fcitx5-daemon.service
nix shell nixpkgs#xprop -c xprop -root XIM_SERVERS
```

运行后检查:

- 微信能登录、收发文字和图片，文件保存到 `~/Documents/WeChat_Data`。
- QQ 能登录，在 Niri/Wayland 下显示窗口，Fcitx/Rime 能输入中文。
- Niri 窗口规则能把微信和 QQ 放到聊天工作区。
- 登录桌面会话后微信会自动启动，Telegram 不会自动启动。
- 微信聊天输入框能正常显示 Fcitx5/Rime 候选框，而不只是接受盲打后的上屏结果。
- 当前会话实测在重启 Fcitx5 和 WeChat 后，微信聊天输入框已恢复显示 Rime 候选框。

## 回滚

如果微信或 QQ 在当前版本不可用，先回滚安装入口:

- 在 `home/linux/gui/base/misc.nix` 注释掉 `bwraps.wechat`。
- 在 `home/linux/gui/base/misc.nix` 注释掉 `nixpaks.qq`。
- 如需回滚 Fcitx5 启动去重，移除 `home/linux/gui/base/fcitx5/default.nix` 中的用户级 `Hidden=true`
  autostart 覆盖；这会重新引入双实例竞争和 XIM 启动时序风险，不建议长期使用。

然后重新构建 Home Manager/NixOS 配置。微信数据目录 `~/Documents/WeChat_Data`
不会因为注释包入口而自动删除。
