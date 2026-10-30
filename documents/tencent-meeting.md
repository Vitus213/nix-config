# Linux 腾讯会议

这份文档记录 NixOS + Niri 上腾讯会议的安装、屏幕共享兼容、数据持久化、验证和回滚方式。

## 当前结论

- 腾讯会议通过主 `nixpkgs` 的 `pkgs.wemeet` 安装，当前锁定版本为 `3.26.10.401`。
- 安装入口是 `home/linux/gui/base/media.nix`，与 Zoom 放在同一组 Home Manager 用户包中。
- Apollo 持久化 `~/.local/share/wemeetapp`，保留登录态和应用数据；`~/.cache/wemeetapp` 不持久化。
- Niri 使用实测 `app-id="wemeetapp"` 将腾讯会议窗口自动放到 `0other` 工作区。
- `overlays/wemeet/` 在原闭源包上构建适配：统一 X11/xcb 启动入口，用本地 `libwemeet-capture.so`
  替换上游旧共享 hook，支持 portal、PipeWire SHM 与 EGL DMA-BUF 导入。
- x86-64 的 `3.26.10.401` 原生主题使用固定二进制身份的蓝灰配色；完整原始源码未恢复。
- Niri 仍保留 `overlays/niri/default.nix`
  的 SHM 回移，兼容其他只接收内存帧的消费者；新腾讯会议采集库已在 NVIDIA
  DMA-BUF 流上运行，不要求当前 compositor 重启后才能使用这条路径。
- Linux 原生本地录制被厂商禁用，转换程序路径函数为空；云录制另有会内权限和服务处理流程，不能把采集补丁或录制指示灯视为完整录制验收。

## 独立客户端重建

用户随后要求替换腾讯闭源核心，继续逆向完整客户端。本机重建目录是
`/home/vitus/work/rea/_reference/wemeet/reconstruction/`，与上面的原包适配分开。独立客户端名为“澄会”，使用系统 Qt5、Python、portal/PipeWire/EGL；运行时不加载
`libwemeet*`、`libxcast.so` 或原腾讯会议进程。现有桌面配置仍使用原适配包。

当前实际完成并验证：

- 原包 3,568 个条目、252 个 ELF、29 份模块声明的身份清单，原生启动与路由恢复，Qt 资源和资源声明解码；反编译输出保留为证据，不称为可编译原始源码。
- 独立二维码获取和轮询实际连接服务；原生账号接口对无效合成授权码返回 HTTP 200、业务错误
  `-52025`。这只验证请求到达服务，不代表真实登录成功。
- 原生签名/URL 编码、QQ-TEA、SSO 封装、PERE
  varint 和 CS1001 序列化已有原库对照；内层认证 XML/AES-CTR 也以合成输入对照到 888 字节完全相同。
- 独立 Wayland 窗口经可见 portal 选择显示器，在 Niri/NVIDIA 上协商 `2560×1440`
  DMA-BUF 并显示持续更新的真实桌面；一次停止后日志记录 1,783 帧，Niri casts 为空。
- `reconstruction/flake.nix` 与 `flake.lock`
  固定同一 nixpkgs 修订，独立 Nix 二进制已构建；本地启动可用
  `nix run /home/vitus/work/rea/_reference/wemeet/reconstruction -- --capture-preview`。
- 独立客户端已接入完整可信会话链路：信令走 `conn.wemeet.tencent.com:443`
  已验证 TLS1.3 证书与主机名校验（端口 443 与 TCP+TLS 枚举来自原库 `InitOptions+0x180` 和
  `CreateTlsTcpConnection` 原始指令证据）；账号资料 `user_district` 的唯一生产者证实为
  `/v2/account/login/refresh-token?refresh_token=0` 的 `data`
  字段（登录令牌不含该字段），后端首次入会时经签名 CGI 拉取，缺失时显式报错。
- 媒体注册映射 `protocol/media_handoff.py`
  将入会接纳响应映射到 dispatch、建房间请求、xcast 偏好树与 TLS 传输参数；`media_platform_auth_token`、CS1002 签名密钥等协商值必须来自实际服务响应，缺失值显式列出而不猜测。三种媒体加密（AES-128/AES-256 计数器流、ChaCha20）已按原库 12/12 合成向量对照实现；H.264 分片预算按原库 40/40 向量对照。
- 本轮恢复并验收（均有永久回归测试）：TIM 普通消息编解码（C2C/群路由、未知字段保留、缺失生产者显式报错）、媒体 dispatch 交换（CS1001 精确 246 字节帧、CS1002 消费产出建房间五参数 room_num=0/location_id=0/signed_key、端点解码与 UDP/TCP 选择规则、重连快照显式拒绝）、PERE 发送流水线（单 NAL/FU-A 分片/音频路径、会话门控、未恢复阶段显式跳过）、成员推送合并规则（0=none,1=join,2=left,
  3=update,4=kick,5=timeout,8/9=权限变化的字面 switch 证据、按键 app_uid_app_id_
  instance_id、补丁/移除/无操作规则）、SelectAbility
  283 服务器推送解码与同序列 284 空应答（客户端无主动请求生产者）、设置内容边界（内层格式未恢复，键名不伪造）与 COS 上传链（服务端授权逐字使用、分片/完成/通知帧）。
- 独立回归测试 86 项全部通过；`nix build` 启用 CTest 后通过，依赖闭包不含任何腾讯组件。媒体运行时
  `client/media_session.py`
  已接入 worker：系统 CA 验证的 TLS 握手（0x36 信封）、dispatch 交换、建房间与 283 自动应答；dispatch 帧的 TLS 传输绑定显式标记为 inferred，待真实会话确认。
- 媒体凭据生产者恢复：`relation_id = av_room_id & 0xffffffff`，`meeting_appid`/ `media_set_type`
  是入会应答根字段（sub_81ed20→0x7dcfe0 字节级证据），媒体会话直接从接纳应答提取。发送路径恢复：app-crypto 直接密钥保护（type
  0x1f、ids 100/101、`0x41`/`0x42`
  明文标记、逐包复位）、UDP 分组信封（`00 ba ba` + 长度记录、上限 1272）、CS1002 端点族/传输解码；DTLS-SRTP 密钥导出仍为显式未恢复项。采集→编码→发送桥完成：PipeWire 帧→libx264
  AnnexB→sender 流水线（libavcodec/ libx264 已链接，编码器 CTest 通过），回归测试 96/96。
- 仍需真实扫码登录后的端到端验证：入会 IQ 实际发送、媒体 dispatch
  CS1001/CS1002 实际交换、房间注册与远端共享画面；Hyprland 未实测；本地录制按用户要求暂缓。

尚未完成的验收包括媒体发送/接收、普通聊天、文件收发和完整设置的端到端验证，因此当前产物仍不能代替完整腾讯会议。会前界面明确标注“尚未发送到会议”。Hyprland未实测；本地录制按用户要求暂缓，待共享和核心替换后继续。新增恢复代码与证据均留在本机分析目录。

## 配置入口

- `home/linux/gui/base/media.nix`：直接安装经过 overlay 覆盖的 `pkgs.wemeet`。
- `overlays/wemeet/default.nix`、`capture.nix`：统一入口、共享库与主题的可复现构建。
- `overlays/wemeet/capture-*.{cpp,hpp}`：XShm、portal、PipeWire、EGL 与窗口边框适配。
- `overlays/wemeet/theme.py`、`theme.json`：固定版本的原生主题修改与原件备份。
- `overlays/niri/default.nix`：固定提交范围与 SHA-256 的 ScreenCast SHM 补丁。
- `hosts/_shared/preservation.nix`：持久化 Apollo 的腾讯会议数据。
- `home/linux/gui/niri/conf/windowrules.kdl`：将腾讯会议窗口分配到 `0other`。

## 当前行为

部署配置后，可以从应用启动器打开“腾讯会议”，也可以运行：

```bash
wemeet
```

当前 Nixpkgs 包从腾讯官方 CDN 获取 `3.26.10.401` deb。仓库的 `wemeet` 命令实际调用原包的
`wemeet-xwayland`；原桌面条目 `Exec=wemeet %u` 和会议 URI handler 因此自动使用同一路径。

2026-10-29 在 Apollo 上以临时 `HOME` 做相同环境对照：原包 `wemeet` 继承 `QT_QPA_PLATFORM=wayland`
后运行 90 秒仍未创建可见窗口；`wemeet-xwayland` 创建了 `app-id="wemeetapp"`
的腾讯会议登录窗口，截图确认界面正常显示。这是当前环境的实测，不表示所有 Niri 机器都必须使用 xcb。

该入口先检测真实 Wayland 会话，再强制 `QT_QPA_PLATFORM=xcb`、`XDG_SESSION_TYPE=x11`，并隐藏
`WAYLAND_DISPLAY`。保留上游 `libwemeetwrap.so` 的音频/文件传输适配；原 `libhook.so` 替换为本仓库的
`libwemeet-capture.so`。Qt 头文件只用于类型声明，运行时继续使用客户端自带 Qt，不链接系统 Qt；继承预加载库的非 Qt 子进程也必须能启动。X11 界面由 xwayland-satellite 承载，共享选源走 portal/PipeWire。共享反馈环见
[Wayland 屏幕共享](./wayland-screen-sharing.md)。

Niri 按 `app-id="wemeetapp"` 匹配腾讯会议。主窗口、辅助窗口和音频接入方式窗口创建后都会自动进入
`0other`；窗口规则不强制平铺或浮动，保留应用自身窗口类型。

## Niri 屏幕共享兼容

当前组件版本为 Niri `26.04`、腾讯会议 `3.26.10.401`、`xdg-desktop-portal 1.22.1`、GNOME portal
`50.0`、PipeWire `1.6.9`。Apollo 使用 NVIDIA RTX 3070 / 驱动 `595.104.02`。

Niri 官方要求会话 D-Bus、PipeWire 和 `xdg-desktop-portal-gnome`。仓库已满足这些条件；GTK
portal 不提供 ScreenCast，不能通过把 GNOME backend 换成 GTK 来解决黑屏。

未打补丁的 Niri `26.04` 只发布带 DRM
modifier 的 DMA-BUF。只接受 SHM 的客户端没有可用交集，会出现 portal 已选屏但共享黑屏、卡住或
`no more input formats`。2026-10-29 在 Apollo 上用只接受无 modifier `BGRx`
的 PipeWire 消费者，直接连接 Niri 的实际显示器流，复现了：

```text
STATE connecting
STATE paused
STATE error no more input formats
```

配置回移上游 PR #1791 的完整 SHM 支持，固定范围为
`9e72e4917ca31baf4010496bf7f4aaf78d34d236...3871a3cd76a4168b2dc7c3da880fbe2702bd8900`，补丁内容使用 SHA-256 校验。未升级整个 nixpkgs 或腾讯会议，也没有替换 portal。

- 能接收 DMA-BUF 的客户端继续协商 GPU 缓冲；只支持 SHM 的客户端可协商 `MemFd`。
- SHM 需要把 GPU 图像读回内存，屏幕共享时会增加复制与 CPU 开销；仅在协商到 SHM 时发生。
- `force-pipewire-invalid-modifier` 只改变 modifier，仍是 DMA-BUF，不能补上缺失的 SHM 路径。
- 上游合并提交是
  `403b283d52c7cdfbb0b775afd506eb92885fba65`；以后升级到包含该提交的 Niri 时，删除此 overlay，避免重复应用补丁。

旧 `wemeet-wayland-screenshare`
项目已因 3.26 原生 Wayland 支持而归档；锁定 Nixpkgs 的 X11 兼容 hook 仍只接收内存帧。本仓库已用新的采集库替换它，保留厂商的会议、音频、编码和网络模块。

采集库在 `XShmGetImage`
第一次读取时启动 portal，普通 Qt 图片上传不触发选屏。用户选择一个窗口或显示器后，经 portal 返回的 PipeWire
fd 连接精确节点，优先提供实际 EGL 支持的 RGB DMA-BUF
modifier，并提供 SHM 格式。GPU 读回在独立 worker 上完成，处理裁剪、变换、通道、stride 和保持比例的缩放，再写入客户端请求的 XImage。最多约 30
FPS；间隔内最后一帧保留到下次 worker
tick，避免桌面停止变化后画面停在旧内容。停止、portal 取消、节点消失和格式切换均释放相应缓冲和会话。

腾讯会议的 `linux_qt::ShadeLine`、`linux_qt::TrackerWidget`
在 xwayland-satellite 下曾变成八张绿色大窗口。新库仅在 Wayland 模式抑制这两个边框类；共享状态条是另一类窗口，保留可见。

### 生效方式

```bash
just local
```

仅更新腾讯会议适配包时，部署后完全退出并重开客户端即可；当前进程不会热换共享库。若同时更新 Niri 的 SHM 回移，需保存工作后重新登录桌面才会更换 compositor。不要直接重启用户会话。

检查腾讯会议日志时，不要把“已弹出 portal”视为共享成功；必须看到远端持续更新的实际画面。

### 共享者本机视图与接收路径

共享者本机没有“共享内容预览”窗口，这是 3.26 桌面端的全平台设计：官方帮助中心《共享屏幕使用指南》写明开始共享后“系统会关闭主窗口”；反编译中
`window_share_view_model.cc` 在开始窗口共享时向 `wemeet://page/inmeeting` 推送
`show: 0`（日志串 "partial share hide inmeeting main
window"）。共享者看到的画面就是被共享的屏幕或窗口本身。演示者视图（帮助中心 topic
1623）只服务于 PPT 放映；二进制里的 `localpreview` 字符串属于外部视频设备功能，与屏幕共享预览无关。

本机与官方行为的两处已知差异：

- 官方绿色角标（`linux_qt::ShadeLine`/`TrackerWidget`）在 xwayland-satellite 下映射为多张全屏绿窗，采集库在 Wayland 模式抑制这两类窗口，因此本机没有共享区域绿框，唯一指示是“您正在共享屏幕”状态条。
- Niri 窗口规则把全部 `wemeetapp` 窗口（含共享工具栏和成员悬浮窗）放到 `0other`
  工作区并平铺，niri 没有跨工作区悬浮。从其他工作区发起共享时，工具栏和悬浮窗留在
  `0other`，当前工作区只剩被共享内容。共享期间需要会议 UI 时用 `Mod+0` 切回 `0other`。
- 官方的“长按工具栏顶部拖拽”依赖 X11 自定位请求，xwayland-satellite不执行这类请求，因此应用内手势移动无效。移动方法：点击聚焦工具栏后按
  `Mod+V` （`toggle-window-floating`）转为浮动，再用 niri 内置的 `Mod+左键拖动`
  放到任意位置。若希望工具栏每次共享自动浮动，可在共享期间用 `niri msg windows`
  取到该窗口标题后为其添加 `open-floating` 窗口规则。

接收黑屏根因（2026-10-30 双端实测定位）：客户端用 NVIDIA
EGL 给 XWayland 视频窗口建 EGLSurface 失败（`eglCreateWindowSurface returned EGL_NO_SURFACE error:3005`），媒体接收与解码都正常（`video_stream_decoder`
每秒输出 2560×1600 帧），黑在最后一步渲染；与 NVIDIA/Wayland 独显直连的社区案例一致（
[arch 论坛 16745](https://forum.archlinuxcn.org/t/topic/16745)、[flathub issue #56](https://github.com/flathub/com.tencent.wemeet/issues/56)、[cnblogs 修复记录](https://www.cnblogs.com/keenli/p/21383446)）。

修复（wrapper 已固化，`overlays/wemeet/default.nix`）：Wayland 会话中为客户端进程导出
`__EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json` 和
`__GLX_VENDOR_LIBRARY_NAME=mesa`，视频层改走 Mesa 软件渲染；纯 X11 会话不受影响。2026-10-30
Apollo 双端实测：远端共享与视频恢复显示；本机反向共享时采集库协商 SHM（
`modifier=0xffffffffffffff`）而非 NVIDIA
DMA-BUF，依赖 Niri 的 SHM 回移补丁，远端确认画面连续。该管线每帧本就读回 CPU，SHM 与 DMA-BUF 读回开销相近。

验收方法与此前记录：第二台设备入会并开启共享，本机确认画面持续更新、可缩放、布局切换按钮可用；本机共享后由远端确认。

## 原生主题

`theme.py` 对 `libwemeet_framework.so` 的固定 x86-64 `.text`
哈希、两个各 88 项的键值表、数值指令与空闲 ELF
padding 逐项验证；修改 45 个浅色和 50 个暗色颜色角色的数值与字符串。主色为 `#245BC4`，正文为
`#172033`，表面为蓝灰中性色。保留白色按钮字、危险/成功/警告语义色、视频、遮罩、图标、字号和布局。浅色/暗色 primary 对白字的计算对比度为 6.23/6.34。

原库压缩备份为 `.vendor-original.gz`，构建时禁止 strip 删除无 section 的 palette
padding；版本或字节不匹配则构建失败，不搜索替换全局颜色。实际选屏框和部分原生文本已确认使用新配色。部分 NXUI 主按钮仍使用自己的颜色来源；外置旧 JSON 的修改未改变像素，已撤回。暗色、内嵌网页及全部功能页面尚未完成视觉验收。

## 录制边界

REA/Ghidra 对这份厂商构建的反汇编确认：`wemeet_common::utils::record::IsLocalRecordEnable()` 在 ELF
`0x4ef150` 无条件返回 `0`，对应 Evidence
`ev_4c732cec3f29314dff011e9217fad3d6493b55171959dc930d9aabf6aa7f30ae`；
`GetTranscodeExecuteFilePath` 在 ELF `0x4e4a00` 不赋值即返回，Evidence
`ev_5ef7b857a1ceb3f638e1da3d7f91d57aa7c60e1c3d06581c6c7ee11036b5c073`。这不是 NixOS/compositor 检测失败；只翻转菜单开关不能产生缺失的本地录制实现。

`IsCloudRecordEnable()` 返回
`1`，但会内权限、账号能力、额度、服务处理仍由腾讯判定。测试会议实际显示云录制状态，尚需完成停止 → 服务处理 → 回放/下载，并确认共享图像和声音。没有用外部录屏器替代腾讯原生本地录制，也没有绕过会内授权。

## 数据持久化

使用隔离的临时 `HOME` 启动 `wemeet` 后，确认应用创建：

- `$XDG_DATA_HOME/wemeetapp`：包含 `Saas/Users`、`Saas/Global` 等持久数据；
- `$XDG_CACHE_HOME/wemeetapp`：QtWebEngine 和运行缓存。

因此 preservation 只保留 `~/.local/share/wemeetapp`。缓存可以重建，不进入持久化列表。

## 版本与来源

- 腾讯会议官网：<https://meeting.tencent.com/>
- 当前主 Nixpkgs 修订：`55bfb4d7437bd4e09ab7cba58a43bd68eb310044`
- 对应 Nixpkgs 包定义：
  <https://github.com/NixOS/nixpkgs/blob/55bfb4d7437bd4e09ab7cba58a43bd68eb310044/pkgs/by-name/we/wemeet/package.nix>
- Niri 官方共享要求：<https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Screencasting.md>
- SHM 上游修复：<https://github.com/niri-wm/niri/pull/1791>
- 社区 SHM 回移实例：<https://github.com/jetjinser/flake/blob/main/troisModules/nixos/config.nix>
- 社区 XWayland 对照方案：<https://github.com/levihuayuzhang/dotfiles/blob/main/nixos/etc/nixos/packages/wemeet.nix>
- Nixpkgs 对 Niri + SHM 兼容路径的讨论：<https://github.com/NixOS/nixpkgs/pull/459399>
- 旧 hook 归档说明：<https://github.com/xuwd1/wemeet-wayland-screenshare#--deprecation-notice-->

`wemeet` 是闭源、`unfree` 软件。仓库已有允许所需非自由软件的 Nixpkgs 策略，本次不新增许可证例外。

## 验证

低风险配置验证：

```bash
nix eval --raw --expr 'let f = builtins.getFlake (toString /home/vitus/nix-config); ps = f.nixosConfigurations.apollo.config.home-manager.users.vitus.home.packages; hits = builtins.filter (p: (p.pname or "") == "wemeet") ps; in (builtins.head hits).version' --impure
nix build .#nixosConfigurations.apollo.pkgs.wemeet --no-link --show-trace
nix build .#nixosConfigurations.apollo.config.programs.niri.package --no-link --show-trace
just test
```

当前适配包通过实际 Apollo `pkgs.wemeet` 构建，随构建执行的两个 CTest 均通过：
`capture-frame-boundaries` 覆盖裁剪、八种变换、RGBA/BGRA、stride、padding 和 letterbox；
`capture-preload-child` 用 `LD_BIND_NOW=1` 验证继承预加载的非 Qt 子进程能启动。 `just test` 返回
`true`，三个受影响 Nix 文件的 `nixfmt --check`
通过。闭源腾讯会议自身的内部单测和集测未随二进制提供，不能宣称它们全部通过。

真实 Niri/NVIDIA 验证使用临时 `HOME` 的专用测试客户端，不替换当前 compositor：

- 新入口显示登录/主窗口；重启专用测试进程后保留其已有登录态并恢复测试会议。
- 会内共享协商 `2560×1440 BGRx`、NVIDIA modifier
  `0x300000000e08014`；一次持续采集 9,828 帧后由 compositor 撤销，客户端报告节点消失并停止，Niri
  casts 随后为空。
- 绿色 `ShadeLine` 窗口不再映射，共享状态条仍显示“您正在共享屏幕”。
- 当前测试会议显示云录制“录制中”和暂停/结束控件；处理后回放/下载尚未验收。
- 原生分享选源框使用新 `#245BC4`
  选中颜色；部分 NXUI 主按钮仍使用厂商颜色，legacy 资源改写未改变实测像素，已撤回。主题脚本在构建副本上再次执行返回
  `already-customized`，库的内容与 mtime 均不变。

证据保留在本机 `/home/vitus/work/rea/_reference/wemeet/`：`record-boundary/`
为录制门控反汇编，`theme-boundary/`
为主题消费者与静态初始化器，运行日志和截图记录 GUI/共享结果。这些是本机分析材料，不是腾讯完整原始源码，也不是其他机器的运行保证。

| 验收项                           | 当前范围与剩余条件                                                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| NixOS x86-64 启动、共享输入链路  | 实际包构建、专用客户端、Niri/NVIDIA 流与清理已验证；远端能收到本机共享已经真实会议确认；本机接收他人共享待双端实测 |
| 录制                             | 云录制 UI 已出现；停止、服务生成、回放和下载待完整验证；原生本地录制未实现                                         |
| 音频、摄像头、中文输入、文件传输 | 保留厂商模块；尚未完成双方音视频、聊天输入法及文件收发验收                                                         |
| 主题                             | 原生浅色界面部分实测；暗色、内嵌网页和全部页面没有完整视觉覆盖                                                     |
| Hyprland、ARM                    | 当前主机没有 Hyprland/Hyprland portal 运行环境；未实测。ARM 不应用 x86-64 主题补丁                                 |

此前 Niri
SHM 回移曾单独构建并通过 194 项上游测试、配置校验和嵌套桌面启动；这份历史结果不证明新采集库的 SHM/Hyprland 路径，也不代替远端会议或录制回放。

### 适配代码进入系统构建

再次核查时，运行中的 Niri 已是带 SHM 补丁的 `mls1s…`，但已安装的腾讯会议仍来自原包
`1y879…`。`overlays/wemeet/` 是未跟踪目录，Git flake 源快照不包含它，因此普通
`nix build .#…pkgs.wemeet` 当时仍选择旧 hook；仓库内已有代码和专用测试产物不等于已部署。

将现有适配目录加入 Git 跟踪后，实际 Apollo 包求值为 `a457…`，采集库为 `bzcsv…`。新包装器在隐藏
`WAYLAND_DISPLAY` 前记录真实会话，设置 `WEMEET_WAYLAND_CAPTURE=1`，并把旧 `libhook.so` 替换为
`libwemeet-capture.so`。Niri 现有补丁无需再次修改或重启。共享采集库构建的两个 CTest 通过，完整系统构建产物为
`/nix/store/c2r7jz0m0hc6lcj522rb4kq5miazma2x-nixos-system-apollo-26.11.20261014.55bfb4d`。

该产物已在 Apollo 激活成功（退出码 `0`），Home Manager `Result=success`，安装入口实际指向
`a457…/bin/wemeet-xwayland`；系统和用户单元没有失败项。本次用与客户端一致的 XShm 读取路径预加载新库，在 Niri/NVIDIA 上进行了两次独立选屏：每次捕获都在相同会话中从红色
`RGB(255,0,0)` 更新到蓝色 `RGB(0,0,255)`，两次均协商 `2560×1440 BGRx`、modifier `0x300000000e08014`
的 DMA-BUF；停止后重建会话成功，最终 `niri msg casts` 为空。

这验证了部署采集库经 portal/PipeWire/EGL 到 XImage 的实际动态画面及重复共享清理，不是仅凭 Streaming 状态判断；腾讯会议编码发送后远端连续画面仍需第二端确认。完全退出并重开腾讯会议即可加载此库，当前 Niri 已运行补丁版，不需要再退出桌面。

### 历史故障：旧 Niri 会话未加载 SHM 补丁

2026-10-29 用户澄清，主要问题是“开始共享看不见东西”，不再按“开始会议即崩溃”判断。当前客户端进程持续运行，音频节点为 running；现有记录没有支持崩溃结论的堆栈。

实际会议共享时，11:10:37 的 Niri 日志确认已通过 portal 选择 `DP-1`，随后出现：

```text
Connecting -> Paused
Paused -> Error("no more input formats")
```

腾讯会议的 PipeWire 视频消费者随后处于 suspended。该记录证明此次共享没有完成格式协商，客户端日志中的屏幕编码活动不能证明已取得真实桌面帧。

当时核对到 `niri.service` PID `1765` 仍运行
`/nix/store/66hps6l05pmbqacdhsl8mskn0nsjjw25-niri-26.04/bin/niri`，而服务新入口为
`/nix/store/mls1s507656zfg63x00w02ar16557rc8-niri-26.04/bin/niri`，SHM 补丁尚未进入运行会话。后续重新登录后已确认运行的是
`mls1s…`；该历史阻塞已解除，当前验证状态以上节为准。

## 回滚

回滚腾讯会议的共享、入口和主题适配：移除
`overlays/wemeet/`，部署后完全退出并重开客户端。overlay 目录由 `overlays/default.nix`
自动导入，不能只留下一个空目录。上游原包会重新提供自己的入口和旧共享 hook；用户登录数据不受此包修改影响。

单独回滚 Niri SHM 回移：移除
`overlays/niri/`，部署后重新登录。新腾讯会议采集库仍可协商 DMA-BUF；其他只支持 SHM 的应用可能重新出现格式协商失败。

完整卸载腾讯会议：

1. 从 `home/linux/gui/base/media.nix` 删除 `wemeet`。
2. 从 `home/linux/gui/niri/conf/windowrules.kdl` 删除 `wemeetapp` 窗口规则。
3. 从共享的 `hosts/_shared/preservation.nix` 删除 `.local/share/wemeetapp`。
4. 重新构建并部署对应主机配置。

删除 preservation 条目后，下一次以临时根目录启动时，未另外备份的腾讯会议登录态和应用数据会丢失。
