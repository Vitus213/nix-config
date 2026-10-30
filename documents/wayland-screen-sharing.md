# Wayland 屏幕共享

这份文档记录 Niri/NVIDIA 桌面上的 portal、PipeWire 与应用级屏幕共享配置，以及飞书、OBS、腾讯会议各自应使用的捕获路径。

## 当前结论

- 不替换 D-Bus，也不替换当前 portal 实现。ASHPD
  Demo 和 OBS 已完成实际选屏、建立 PipeWire 流和实时预览，证明会话总线、`xdg-desktop-portal`、`xdg-desktop-portal-gnome`、Niri
  ScreenCast、PipeWire 与 NVIDIA 导入链路可用。
- 飞书保持 XWayland 运行，但通过 `WebRTCPipeWireCapturer`
  强制屏幕共享使用 portal/PipeWire。未启用该参数时，飞书同包 Chromium 的 X11 整屏缩略图为黑屏；启用后会打开 portal，并收到实时整屏画面。
- OBS 必须新增 `Screen Capture (PipeWire)` source。`Display Capture (XSHM)`
  是 X11 捕获路径，在 Niri 下不能代替 portal/PipeWire。
- 腾讯会议的 `wemeet` 命令与应用菜单统一调用 X11/xcb 入口；`overlays/wemeet/`
  保留上游音频适配，以本地 portal/PipeWire/EGL 采集库替换旧共享 hook，可导入 NVIDIA
  DMA-BUF 并支持 SHM。Niri `26.04`
  的 SHM 回移继续兼容其他内存帧消费者。会内共享流与边框已实测，远端画面和完整录制仍按功能逐项验收，详见
  [Linux 腾讯会议](./tencent-meeting.md)。

## 当前版本

排障与验证基于 2026-08-16 的实际运行环境：

- Niri `26.04`
- `xdg-desktop-portal` `1.20.4`
- `xdg-desktop-portal-gnome` `50.0`
- `xdg-desktop-portal-gtk` `1.15.3`
- PipeWire `1.6.5`
- NVIDIA 驱动 `595.84`
- OBS Studio `32.1.2`
- 飞书 `7.66.10`
- 腾讯会议 `3.26.10.401`
- Nixpkgs revision `65179426c83bb3f6bc14898b42ea1c6f01d374b0`

2026-10-29 的腾讯会议适配使用 Niri `26.04`、portal `1.22.1`、GNOME portal `50.0`、PipeWire
`1.6.9`、NVIDIA `595.104.02`，主 Nixpkgs 为
`9013764fcc0ea99fa16cf7aa7decf8a5c3889dd2`。上述飞书故障记录保留其当时版本与实测结论。

## 配置入口

- `modules/nixos/desktop/xdg.nix`：系统 portal 包与 `xdgOpenUsePortal`。
- Niri 包的
  `share/xdg-desktop-portal/niri-portals.conf`：Niri 官方提供的 backend 路由，ScreenCast 使用 GNOME，其余接口由已有 GTK/GNOME
  backend 处理。
- `home/linux/gui/base/misc.nix`：飞书包覆盖，加入 `--enable-features=WebRTCPipeWireCapturer`。
- `home/linux/gui/base/creative.nix`：OBS 与插件。
- `home/linux/gui/base/media.nix`：腾讯会议包。
- `overlays/niri/default.nix`：ScreenCast 的 SHM 回退补丁。

当前 portal 路径是：

```text
应用
  -> org.freedesktop.portal.Desktop
  -> xdg-desktop-portal-gnome (ScreenCast picker/backend)
  -> org.gnome.Mutter.ScreenCast (由 Niri 实现)
  -> PipeWire stream
  -> 应用导入视频帧
```

`xdg-desktop-portal-gtk` 仍处理文件选择等通用接口，但不承担当前 ScreenCast。

## 飞书

飞书 `7.66.10`
继续运行在 XWayland。Nixpkgs 包定义明确暂不启用原生 Wayland，因为上游仍存在原生 Wayland 崩溃问题；本仓库不覆盖这一保护策略。

XWayland 应用默认使用 X11 desktop
capturer，只能看到 XWayland 内容，无法正确捕获 Niri 的完整 Wayland 桌面。当前包覆盖为：

```nix
feishu.override {
  commandLineArgs = "--enable-features=WebRTCPipeWireCapturer";
}
```

该参数只改变 `getDisplayMedia()` 的捕获后端，不把飞书切到原生 Wayland。

A/B 反馈环：

- 无参数：Chromium 内置选择器显示 `Entire Screen`/`Window`，整屏缩略图全黑，没有 portal 请求。
- 有参数：先出现 GNOME portal 选源器；批准显示器后，Chromium 选择器收到实时递归桌面缩略图。

### 部署后必须重启飞书进程

`commandLineArgs` 在构建期通过 `wrapProgram --add-flags` 注入 `$out/opt/bytedance/feishu/feishu`
这个 wrapper。已启动的飞书进程不会因为 Home
Manager 切换而换参数，会一直沿用旧构建。因此部署后如果飞书仍在共享时黑屏，先确认运行进程是否带参数，再决定是否需要重启。

运行时验证（只读）：

```bash
# 主进程 cmdline 必须含 enable-features=WebRTCPipeWireCapturer
pgrep -af "opt/bytedance/feishu/feishu" | rg -v "type=|crashpad"
```

2026-08-16 实测根因：profile 已在 12:44 切到带参数的新构建，但飞书进程 12:31 就已启动，跑的是旧构建
`93yrpg…`（wrapper 无该参数），故共享仍黑屏。kill 旧进程后由 niri 重新拉起，`/proc/<pid>/cmdline`
即含该参数。

2026-08-16 真实会议复测（pw-mon 抓取 PipeWire 协商）结论：当时未提供 SHM 的 Niri 与飞书桌面客户端在本机（NVIDIA +
Niri）无法建立共享流：

- 提供方（niri）只发布 GPU DMA-BUF 缓冲（`BGRx + modifier`）。
- 消费方（飞书 WebRTC，X11 路径）请求 BGRA/RGBA/BGRx/RGBx 但**不能导入 DMA-BUF**，交集为空，niri 报
  `StartCast: Paused -> Error("no more input formats")`，流从未建立。
- 飞书 7.66.10 二进制强制 X11：`--ozone-platform=wayland` 与 `NIXOS_OZONE_WL=1`
  均不生效（进程无 wayland-1 fd，消费节点仍
  `window.x11.display=:0`）；nixpkgs 因上游原生 Wayland 崩溃 bug 明确禁用，本仓库不覆盖。
- 对照：OBS（`Screen Capture (PipeWire)`）与 Zen/Chromium 原生 Wayland 的 portal 路径都能导入 DMA-BUF，同一提供方下共享正常。

已证伪并回滚的尝试：`debug { force-pipewire-invalid-modifier; }`（只改 modifier 不改缓冲类型，且会把 niri 发布格式过滤到只剩 invalid，可能拖累 OBS）；`--ozone-platform=wayland`。保留
`--enable-features=WebRTCPipeWireCapturer`（它把捕获切到 portal，是必要前提，且对 Zen/Chromium 有效）。

2026-10-29 补充：当前回移的 Niri SHM 支持直接补齐上述消费者缺少的缓冲类型；它与
`force-pipewire-invalid-modifier`
不同。旧版本的飞书失败不能用于断言打补丁后仍失败，但本次没有重新验证飞书真实会议，实际远端画面仍需复测。

可行替代：需要共享屏幕时用
**Zen（原生 Wayland）打开飞书网页版会议**，浏览器 portal 路径已验证可收到实时画面；或用 OBS 采集后推流。

## OBS

在 Sources 面板新增：

```text
Screen Capture (PipeWire)
```

不要选择 `Display Capture (XSHM)`。实际测试中，portal 选中 DP-1 后，OBS 日志确认：

```text
Format: BGRx
Size: 2560x1440
Stream state: streaming
```

OBS 预览同时显示实时递归桌面画面，证明当前 OBS `32.1.2` 在本机 NVIDIA 栈上可用。

## 腾讯会议

当前 Nixpkgs 包为 `wemeet 3.26.10.401`。`overlays/wemeet/` 统一 `wemeet` 与 `wemeet-xwayland`
入口，应用菜单和会议 URI handler 均使用同一路径：

```bash
wemeet
```

2026-10-29 在当前 Niri/NVIDIA 环境做相同临时 `HOME` 对照：原包 `wemeet`
以原生 Wayland 运行但未创建可见窗口；X11/xcb 入口正常显示登录页，窗口 app-id 仍为
`wemeetapp`。此入口保留音频/文件传输适配，用本地 `libwemeet-capture.so` 替换旧SHM-only
`libhook.so`，可直接导入 NVIDIA DMA-BUF，也提供 SHM。不加载原生 Wayland 专用的 focus/camera
fix，也不强制 Mesa EGL。

Niri 侧另有独立的缓冲协商约束：原版 `26.04` 只提供 DMA-BUF，只接受 SHM 的消费者在选屏后报
`no more input formats`。当前 overlay 回移
[上游 SHM 支持](https://github.com/niri-wm/niri/pull/1791)，保留 DMA-BUF 并增加
`MemFd`。本机修改前用无 modifier `BGRx`
消费者复现了此错误。该修复需要构建部署后重新登录 Niri 会话，不能靠 KDL 热重载生效；完整步骤见
[Linux 腾讯会议](./tencent-meeting.md#niri-屏幕共享兼容)。

此前真实会议选中 `DP-1` 后报 `no more input formats`
时，运行的仍是旧 Niri。现在运行进程已加载 SHM 补丁；新腾讯会议采集库也已纳入 Git
flake 源并部署，避免继续使用旧 hook。实际 XShm 采集验证在两次独立选屏中均收到红色变蓝色的像素，停止后 casts 为空。该证据覆盖本机动态采集与重复启动，远端会议接收仍需确认；仅重开腾讯会议即可加载新库。

## 低风险验证

```bash
# portal backend 与版本
systemctl --user status xdg-desktop-portal.service
systemctl --user status xdg-desktop-portal-gnome.service
pipewire --version

# 构建 Home Manager 实际选择的飞书包
nix build --impure --no-link --print-out-paths --expr '
  let
    f = builtins.getFlake (toString /home/vitus/nix-config);
    packages = f.nixosConfigurations.apollo.config.home-manager.users.vitus.home.packages;
  in
    builtins.head (builtins.filter (p: (p.pname or "") == "feishu") packages)
'

# 构建 Niri 共享兼容包；腾讯会议菜单与命令均使用 xcb
nix build .#nixosConfigurations.apollo.config.programs.niri.package --no-link
wemeet
```

部署后应分别确认：

- 飞书进入会议后，点击屏幕共享会打开 portal，选中显示器后远端能看到持续更新的画面。
- OBS 的 `Screen Capture (PipeWire)` source 有实时预览。
- 腾讯会议可共享持续更新的远端画面，停止后能再次共享；两个命令已统一为 xcb，不能再作为后端 A/B 对照。

## 回滚

1. 将 `home/linux/gui/base/misc.nix` 中的飞书包覆盖恢复为普通 `feishu`。
2. 重新部署 Home Manager/NixOS 配置。
3. OBS 只需删除测试 scene/source，不涉及声明式配置回滚。
4. 回滚 Niri SHM 支持：删除 `overlays/niri/`，重新部署并登录桌面；会恢复仅 DMA-BUF 的协商行为。
5. 回滚腾讯会议默认 xcb：将 `home/linux/gui/base/media.nix` 的腾讯会议包装恢复为普通
   `wemeet`，部署后重新启动客户端。

## 参考

- ScreenCast
  portal：<https://flatpak.github.io/xdg-desktop-portal/docs/doc-org.freedesktop.portal.ScreenCast.html>
- 当前 Nixpkgs 飞书包：<https://github.com/NixOS/nixpkgs/blob/9013764fcc0ea99fa16cf7aa7decf8a5c3889dd2/pkgs/by-name/fe/feishu/package.nix>
- 当前 Nixpkgs 腾讯会议包：<https://github.com/NixOS/nixpkgs/blob/9013764fcc0ea99fa16cf7aa7decf8a5c3889dd2/pkgs/by-name/we/wemeet/package.nix>
- Niri SHM 支持：<https://github.com/niri-wm/niri/pull/1791>
