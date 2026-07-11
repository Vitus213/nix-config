# Linux 腾讯会议

这份文档记录 NixOS 图形桌面上腾讯会议的当前安装方式、数据持久化、验证和回滚方式。

## 当前结论

- 腾讯会议通过主 `nixpkgs` 的 `pkgs.wemeet` 安装，当前锁定版本为 `3.26.10.401`。
- 安装入口是 `home/linux/gui/base/media.nix`，与 Zoom 放在同一组 Home Manager 用户包中。
- Apollo 和 Athena 持久化 `~/.local/share/wemeetapp`，保留登录态和应用数据；`~/.cache/wemeetapp`
  不持久化。
- Niri 使用实测 `app-id="wemeetapp"` 将腾讯会议窗口自动放到 `0other` 工作区。
- 当前直接运行 Nixpkgs 包，不额外添加 Nixpak 或 bubblewrap 沙箱。摄像头、麦克风和 Wayland 屏幕共享依赖较多，先保持 Nixpkgs 已验证的运行环境。

## 配置入口

- `home/linux/gui/base/media.nix`：安装 `pkgs.wemeet`。
- `hosts/olympians-apollo/preservation.nix`：持久化 Apollo 的腾讯会议数据。
- `hosts/olympians-athena/preservation.nix`：持久化 Athena 的腾讯会议数据。
- `home/linux/gui/niri/conf/windowrules.kdl`：将腾讯会议窗口分配到 `0other`。

## 当前行为

部署配置后，可以从应用启动器打开“腾讯会议”，也可以运行：

```bash
wemeet
```

当前 Nixpkgs 包从腾讯官方 CDN 获取 `3.26.10.401` deb，并提供 `wemeet` 和 `wemeet-xwayland`
两个命令。默认 `wemeet` 包装器包含：

- Wayland 屏幕共享 hook；
- Wayland 下摄像头预览修复；
- Wayland/X11 输入焦点崩溃修复；
- 音频设备识别和文件传输兼容修复。

默认先使用 `wemeet`。仅当默认模式无法正常显示窗口时，才用 `wemeet-xwayland`
做对照；后者会强制 X11/xcb，不是当前默认入口。

Niri 按 `app-id="wemeetapp"` 匹配腾讯会议。主窗口、辅助窗口和音频接入方式窗口创建后都会自动进入
`0other`；窗口规则不强制平铺或浮动，保留应用自身窗口类型。

## 数据持久化

使用隔离的临时 `HOME` 启动 `wemeet` 后，确认应用创建：

- `$XDG_DATA_HOME/wemeetapp`：包含 `Saas/Users`、`Saas/Global` 等持久数据；
- `$XDG_CACHE_HOME/wemeetapp`：QtWebEngine 和运行缓存。

因此 preservation 只保留 `~/.local/share/wemeetapp`。缓存可以重建，不进入持久化列表。

## 版本与来源

- 腾讯会议官网：<https://meeting.tencent.com/>
- 当前 Nixpkgs 修订：`0c88e1f2bdb93d5999019e99cb0e61e1fe2af4c5`
- 对应 Nixpkgs 包定义：
  <https://github.com/NixOS/nixpkgs/blob/0c88e1f2bdb93d5999019e99cb0e61e1fe2af4c5/pkgs/by-name/we/wemeet/package.nix>

`wemeet` 是闭源、`unfree` 软件。仓库已有允许所需非自由软件的 Nixpkgs 策略，本次不新增许可证例外。

## 验证

低风险配置验证：

```bash
nix eval --raw --expr 'let f = builtins.getFlake (toString /home/vitus/nix-config); ps = f.nixosConfigurations.apollo.config.home-manager.users.vitus.home.packages; hits = builtins.filter (p: (p.pname or "") == "wemeet") ps; in (builtins.head hits).version' --impure
nix build .#nixosConfigurations.apollo.pkgs.wemeet --no-link --show-trace
```

部署后还需要实际确认：

- 能登录并保持登录态；
- 扬声器、麦克风和摄像头可用；
- Niri/Wayland 下可以选择窗口或显示器并共享画面；
- Fcitx5/Rime 可以在聊天输入框输入中文；
- 从其他工作区启动后，所有 `wemeetapp` 窗口进入 `0other`；
- 文件发送和接收正常。

本次没有执行 `just local`、`just local-host` 或
`nixos-rebuild switch`，因为这些命令会切换当前系统；实际会议功能不能由构建验证代替。

## 回滚

1. 从 `home/linux/gui/base/media.nix` 删除 `wemeet`。
2. 从 `home/linux/gui/niri/conf/windowrules.kdl` 删除 `wemeetapp` 窗口规则。
3. 从 Apollo 和 Athena 的 `preservation.nix` 删除 `.local/share/wemeetapp`。
4. 重新构建并部署对应主机配置。

删除 preservation 条目后，下一次以临时根目录启动时，未另外备份的腾讯会议登录态和应用数据会丢失。
