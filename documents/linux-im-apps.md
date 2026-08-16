# Linux 微信、QQ 与飞书

这份文档记录 NixOS 桌面上微信、QQ 和飞书的当前安装方式、沙箱边界、屏幕共享、验证和回滚方式。

## 当前结论

- 微信使用官方 Linux WeChat AppImage `4.1.1.4`，通过 `bwraps.wechat` 封装后安装。
- QQ 使用官方 Linux QQ `3.2.29-2026-05-28`，通过 `nixpaks.qq` 封装后安装。
- QQ 的封装从主 `nixpkgs` 的 `pkgs.qq` 派生，并在 `hardening/nixpaks/default.nix`
  中局部固定官方 deb 的 URL 和 hash。
- 两者都在 `home/linux/gui/base/misc.nix` 进入 Home Manager 用户包列表。
- Linux GUI 会话默认自启动微信，不再默认自启动 Telegram；两者仍保留在用户包中。
- 不把 Flatpak 作为主方案；Flatpak 只作为临时排障或对照方案。

- 飞书使用主 `nixpkgs` 的 `pkgs.feishu 7.66.10`，保持 XWayland，并通过 `WebRTCPipeWireCapturer`
  将屏幕共享切到 portal/PipeWire。

## 配置入口

- `home/linux/gui/base/misc.nix`: 启用 `bwraps.wechat` 和 `nixpaks.qq`。
- `home/linux/gui/base/misc.nix`: 对 `pkgs.feishu` 覆盖启动参数
  `--enable-features=WebRTCPipeWireCapturer`。
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
- Fcitx5 只由 `fcitx5-daemon.service` 启动；启动前通过 `xprop -root` 触发 Niri 的按需 XWayland。
  `fcitx5-xim-recovery.timer` 每 10 秒检查 `XIM_SERVERS`，属性缺失时自动重启 Fcitx5。

QQ:

- 版本固定为 `3.2.29-2026-05-28`。
- 通过 Nixpak 运行，不直接裸跑 `pkgs.qq`。
- 可读写 Documents、Downloads、Music、Videos、Pictures 这些常用用户目录。
- 使用 Wayland 和 PipeWire socket，不启用 X11 socket。

飞书:

- 版本为 `7.66.10`，跟随主 `nixpkgs`。
- 保持 XWayland；Nixpkgs 当前明确不启用原生 Wayland，避免上游已知崩溃。
- 屏幕共享通过 `WebRTCPipeWireCapturer` 调用 xdg-desktop-portal 和 PipeWire。
- 实测无该参数时整屏缩略图为黑屏；加入参数后 portal 能返回实时 Niri 桌面画面。
- 详细反馈环、OBS 与腾讯会议对照见 [Wayland 屏幕共享](./wayland-screen-sharing.md)。

## 为什么这样选

- Nixpkgs 已经包含 Linux WeChat `4.1.1.4`，来源是腾讯官方 Linux AppImage。
- 当前 QQ 固定到
  `3.2.29-2026-05-28`，来源是腾讯 QQNT 官方 deb；固定 URL 和 hash 是为了避免上游下载地址变动导致旧 Nixpkgs 版本的
  `pkgs.qq` 失效。
- Flathub 的 QQ manifest 也采用 `QQ_3.2.29_260528`，并显式配置 Wayland 输入法相关参数。
- Flathub 的 WeChat manifest 仍设置
  `QT_QPA_PLATFORM=xcb`，说明当前微信 Linux 客户端更适合按 X11/xcb 路径运行。
- 微信和 QQ 都是闭源 IM，应限制其默认读取整个家目录的能力；本仓库已有 Nixpak/bubblewrap 结构，比直接安装裸包更符合当前加固习惯。
- 飞书原生 Wayland 仍有上游崩溃风险，因此显示后端保持 XWayland；仅把捕获后端切到 portal/PipeWire，避免 X11
  desktop capturer 无法看到 Wayland 桌面。
- WeChat `4.1.1.4` 同时看到 Wayland 和 X11 环境时可能改走 Fcitx
  Portal；该路径的候选框坐标在 Niri/XWayland 下可能落到屏幕外。系统 XDG autostart 与 Home
  Manager 服务同时启动 Fcitx5 时，过早启动的实例也会导致 XIM 未注册，因此当前只保留 Home
  Manager 服务。
- Niri `26.04` 会按需管理 `xwayland-satellite`。实测显示器断连时 satellite 可能以状态 `101`
  退出，Fcitx5 随后丢失 XCB 连接；Niri 虽会拉起新的 satellite，Fcitx5 `5.1.21`
  不会自动重新注册 XIM。当前用定时健康检查发现缺失的 `XIM_SERVERS`
  并重启 Fcitx5，恢复注册；微信沙箱继续隐藏 Wayland 并强制使用 XIM。

参考:

- Nixpkgs WeChat:
  <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/we/wechat/package.nix>
- Nixpkgs QQ: <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/qq/qq/sources.nix>
- Flathub WeChat:
  <https://github.com/flathub/com.tencent.WeChat/blob/master/com.tencent.WeChat.yaml>
- Flathub QQ: <https://github.com/flathub/com.qq.QQ/blob/master/com.qq.QQ.yaml>
- Nixpkgs Feishu：
  <https://github.com/NixOS/nixpkgs/blob/65179426c83bb3f6bc14898b42ea1c6f01d374b0/pkgs/by-name/fe/feishu/package.nix>

## 验证

低风险配置验证:

```bash
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.home.packages --show-trace
nix eval --json --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in flake.nixosConfigurations.apollo.config.home-manager.users.vitus.xdg.autostart.entries' --impure
nix eval --raw --expr 'let flake = builtins.getFlake (toString /home/vitus/nix-config); in flake.nixosConfigurations.apollo.config.home-manager.users.vitus.xdg.configFile."autostart/org.fcitx.Fcitx5.desktop".text' --impure
nix eval --raw .#nixosConfigurations.apollo.pkgs.feishu.version
```

完整构建验证：

```bash
nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace
nix build .#nixosConfigurations.athena.config.system.build.toplevel --no-link --show-trace
```

运行时确认 Fcitx5 服务与 XIM：

```bash
systemctl --user is-active fcitx5-daemon.service
systemctl --user is-active fcitx5-xim-recovery.timer
nix shell nixpkgs#xprop -c xprop -root XIM_SERVERS
# 预期输出：XIM_SERVERS(ATOM) = @server=fcitx
fcitx5-diagnose
```

运行后检查:

- 微信能登录、收发文字和图片，文件保存到 `~/Documents/WeChat_Data`。
- QQ 能登录，在 Niri/Wayland 下显示窗口，Fcitx/Rime 能输入中文。
- 飞书能登录；进入会议后屏幕共享会打开 portal，选择显示器后远端画面持续更新。
- Niri 窗口规则能把微信和 QQ 放到聊天工作区。
- 登录桌面会话后微信会自动启动，Telegram 不会自动启动。
- 微信聊天输入框能正常显示 Fcitx5/Rime 候选框，而不只是接受盲打后的上屏结果。
- `fcitx5-diagnose` 中微信位于 `Group [x11::0]`，输入上下文前端为 `fcitx4`，而不是 `wayland_v2`。
- 故障注入终止 `xwayland-satellite` 后，恢复脚本能重启 Fcitx5，并重新建立
  `XIM_SERVERS(ATOM) = @server=fcitx`。

## 回滚

如果微信或 QQ 在当前版本不可用，先回滚安装入口:

- 在 `home/linux/gui/base/misc.nix` 注释掉 `bwraps.wechat`。
- 在 `home/linux/gui/base/misc.nix` 注释掉 `nixpaks.qq`。
- 如需回滚飞书 PipeWire 捕获参数，将 `home/linux/gui/base/misc.nix` 中的 `feishu.override`
  恢复为普通 `feishu`。
- 如需回滚 Fcitx5 启动去重，移除 `home/linux/gui/base/fcitx5/default.nix` 中的用户级 `Hidden=true`
  autostart 覆盖；这会重新引入双实例竞争和 XIM 启动时序风险，不建议长期使用。

然后重新构建 Home Manager/NixOS 配置。微信数据目录 `~/Documents/WeChat_Data`
不会因为注释包入口而自动删除。
