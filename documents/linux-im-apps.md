# Linux 微信、QQ 与飞书

这份文档记录 NixOS 桌面上微信、QQ 和飞书的当前安装方式、沙箱边界、屏幕共享、验证和回滚方式。

## 当前结论

- 微信使用官方 Linux WeChat DEB `4.1.13.26`，直接运行
  `pkgs.wechat`，默认原生 Wayland；不使用沙箱或隔离数据路径。
- QQ 当前暂停安装，不从 Home
  Manager 用户包列表引入；对应 Nixpak 包装源码暂保留，避免影响后续重新启用。
- 微信进入 `home/linux/gui/base/misc.nix` 的 Home Manager 用户包列表。
- Linux GUI 会话默认自启动微信，不再默认自启动 Telegram；两者仍保留在用户包中。
- 不把 Flatpak 作为主方案；Flatpak 只作为临时排障或对照方案。

- 飞书使用主 `nixpkgs` 的 `pkgs.feishu 7.66.10`，保持 XWayland，并通过 `WebRTCPipeWireCapturer`
  将屏幕共享切到 portal/PipeWire。

## 配置入口

- `home/linux/gui/base/misc.nix`: 启用 `pkgs.wechat`，并对 `pkgs.feishu` 覆盖启动参数
  `--enable-features=WebRTCPipeWireCapturer`；QQ 当前不在用户包列表中。
- `home/linux/gui/base/xdg/autostart.nix`: 将微信桌面条目加入 XDG
  autostart，并移除 Telegram 自启动条目。
- `home/linux/gui/base/fcitx5/default.nix`: 禁用系统 Fcitx5 XDG autostart，只保留 Home
  Manager 服务。
- `overlays/wechat/default.nix`、`overlays/wechat/package.nix`: 局部回移的 Linux
  DEB 配方、固定下载源与 hash、应用局部的 Wayland/输入法环境，不更新主 `nixpkgs`。
- `hardening/nixpaks/qq.nix`、`hardening/nixpaks/default.nix`: 保留 QQ 包装实现，但当前不接入用户包列表。

## 当前行为

微信:

- 版本固定为 `4.1.13.26`；不是自动追踪腾讯滚动下载地址。
- Linux DEB 配方回移自 Nixpkgs 提交
  `ea41ebe3e788f3f374e04885f4f60aca20efefed`，依赖仍来自本仓库锁定的主 `nixpkgs`。
- 官方下载对象身份匹配时优先下载官方源，否则使用固定归档，最终都校验 SHA-256。
- 使用真实家目录和应用默认数据路径（如
  `~/.xwechat`、`~/xwechat_files`），不改写 HOME/XDG 变量，不挂载隔离路径。
- 旧 `~/Documents/WeChat_Data`
  原样保留，不自动迁移、合并或删除；普通家目录已有的微信数据不会被配置脚本覆盖。
- 微信局部设置 `QT_QPA_PLATFORM=wayland`、`QT_IM_MODULE=text-input-unstable-v3`，保留
  `WAYLAND_DISPLAY`，不再强制 xcb/Fcitx 模块。
- 微信局部设置 `NIXOS_OZONE_WL=1`，供上游 WeChatAppEx 子进程包装选择 Wayland；保留 GL/EGL 与 FFmpeg
  ABI 修补。
- NVIDIA 使用系统驱动与 EGL 配置；不再需要 FHS 层透传，也不用包内 Mesa 代替宿主驱动。
- XDG autostart 使用 `pkgs.wechat` 的 `wechat.desktop`，登录桌面会话后自动启动微信。
- Fcitx5/Rime 小鹤双拼保持不变，中文引擎不承担图片剪贴板格式转换。
- Fcitx5 仍由唯一的 `fcitx5-daemon.service` 启动；XWayland 探测和 `fcitx5-xim-recovery.timer`
  为其他 X11 应用保留，不是新版微信的输入前提。
- 微信具有普通桌面应用的用户文件和会话访问权限；已移除微信专用 bubblewrap/FHS 包装及其主机导入。

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

- 新版官方 Linux 微信支持原生 Wayland；局部回移已维护的 DEB 配方，避免为更新单个应用升级整个系统或另引一套 Nixpkgs 包集合。
- 当前 QQ 固定到
  `3.2.29-2026-05-28`，来源是腾讯 QQNT 官方 deb；固定 URL 和 hash 是为了避免上游下载地址变动导致旧 Nixpkgs 版本的
  `pkgs.qq` 失效。
- Flathub 的 QQ manifest 也采用 `QQ_3.2.29_260528`，并显式配置 Wayland 输入法相关参数。
- 当前 Flathub 微信清单也使用 Wayland；本仓库按用户选择直接运行 Nix 安装的微信，不启用 Flatpak 或额外沙箱。
- 直接运行意味着微信可读取当前用户有权访问的文件；QQ 等其他应用的 Nixpak 配置保持不变。
- 飞书原生 Wayland 仍有上游崩溃风险，因此显示后端保持 XWayland；仅把捕获后端切到 portal/PipeWire，避免 X11
  desktop capturer 无法看到 Wayland 桌面。
- 原生 Wayland 使用
  `text-input-v3`，减少微信主窗口对 XWayland 和旧输入法坐标路径的依赖；不代表截图粘贴故障已经经登录后验收修复。
- 仓库全局已设置
  `QT_QPA_PLATFORM=wayland`，会跳过新版上游启动器“变量为空时”的自动选择分支，因此微信启动器同时显式设置平台和输入法模块。
- XIM 恢复服务继续服务 XWayland 应用；新版微信不再要求诊断结果为 `x11::0` 或 `fcitx4`。

参考:

- Nixpkgs WeChat:
  <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/we/wechat/package.nix>
- 固定回移来源：
  <https://github.com/NixOS/nixpkgs/tree/ea41ebe3e788f3f374e04885f4f60aca20efefed/pkgs/by-name/we/wechat>
- Fcitx Wayland 接入： <https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland>
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
nix eval --raw .#nixosConfigurations.apollo.pkgs.wechat.version
nix build .#nixosConfigurations.apollo.pkgs.wechat --no-link --show-trace
```

完整构建验证：

```bash
nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace
nix build .#nixosConfigurations.generic.config.system.build.toplevel --no-link --show-trace
```

运行时确认 Fcitx5 服务与 XIM：

```bash
systemctl --user is-active fcitx5-daemon.service
systemctl --user is-active fcitx5-xim-recovery.timer
nix shell nixpkgs#xprop -c xprop -root XIM_SERVERS
# 预期输出：XIM_SERVERS(ATOM) = @server=fcitx
fcitx5-diagnose
```

本次接入验证（未执行系统切换）：

- `just test` 返回 `true`，新版 `pkgs.wechat` 实际构建成功。
- Apollo、Athena、Generic 的包版本、用户安装项与 autostart 均为 `4.1.13.26`，旧 `bwraps`
  属性已移除；三台主机的系统 derivation 求值通过，未构建完整系统。
- 直接启动实际构建产物，以临时 HOME 保护已有数据，未使用测试沙箱；观察到二维码登录界面，Niri 的窗口 PID 对应新版微信二进制，进程环境为 Wayland/text-input-v3。
- 试验窗口、临时 HOME、日志和截图已清理，原微信进程未替换。登录后的图片粘贴、候选框与小程序仍需用户实际验收。

运行后检查:

- 微信能登录、收发文字和图片，使用普通家目录中的应用默认数据路径，不再写入隔离的 `WeChat_Data`。
- QQ 能登录，在 Niri/Wayland 下显示窗口，Fcitx/Rime 能输入中文。
- 飞书能登录；进入会议后屏幕共享会打开 portal，选择显示器后远端画面持续更新。
- Niri 窗口规则能把微信和 QQ 放到聊天工作区。
- 登录桌面会话后微信会自动启动，Telegram 不会自动启动。
- 微信聊天输入框能正常显示 Fcitx5/Rime 候选框，而不只是接受盲打后的上屏结果。
- 用 `niri msg --json windows` 检查微信主窗口的 PID 对应实际微信进程，而不是
  `xwayland-satellite`；不能只凭 app-id 判断协议。
- 检查截图复制后的 Ctrl+V 与右键粘贴是否出现图片预览，再分别检查文件选择、保存和小程序。
- XIM 健康检查仅验证其他 XWayland 应用的兼容路径，不作为新版微信原生 Wayland 输入验收。

## 回滚

### 切换前备份与版本回滚

先从微信菜单正常退出，再备份旧 `~/Documents/WeChat_Data`
和普通家目录中已有的微信数据。新旧版本不得同时读写同一份数据。此次配置变更不迁移或合并数据；旧隔离目录不会自动接入新版。

配置 rebuild 不会替换已运行的旧进程；rebuild 后重新启动微信才使用新包。首次打开旧数据可能升级数据库，不能假设旧版可读取新版修改后的数据。Nix
generation 回滚不恢复应用数据；需要降级时，恢复旧包及升级前的配套数据备份。

普通家目录若已有
`~/xwechat_files`，首次使用新版时先核对账号和数据设置，不用旧隔离目录覆盖它。如需迁移旧记录，必须退出微信后单独确认迁移方案，避免混合两份数据库和附件目录。

如果微信或 QQ 在当前版本不可用，先回滚安装入口:

- 在 `home/linux/gui/base/misc.nix` 注释掉 `wechat`，并移除其 autostart 条目。
- 在 `home/linux/gui/base/misc.nix` 注释掉 `nixpaks.qq`。
- 如需回滚飞书 PipeWire 捕获参数，将 `home/linux/gui/base/misc.nix` 中的 `feishu.override`
  恢复为普通 `feishu`。
- 如需回滚 Fcitx5 启动去重，移除 `home/linux/gui/base/fcitx5/default.nix` 中的用户级 `Hidden=true`
  autostart 覆盖；这会重新引入双实例竞争和 XIM 启动时序风险，不建议长期使用。

然后重新构建 Home Manager/NixOS 配置。普通家目录中的微信数据和旧 `~/Documents/WeChat_Data`
都不会因为移除包入口而自动删除。
