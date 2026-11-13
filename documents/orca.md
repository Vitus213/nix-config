# Orca 移除说明

## 当前行为

仓库已移除 StablyAI Orca，不再为 Linux 图形桌面安装或自动启动该应用：

- `home/linux/gui/base/misc.nix` 不再包含 `stably-orca`。
- `home/linux/gui/base/xdg/autostart.nix` 不再安装 `orca.desktop` 自启动项。
- `home/linux/gui/niri/conf/windowrules.kdl` 不再包含 Orca 的 `5code` 工作区规则。
- 专用的 `overlays/stably-orca/` 已删除，不再提供 `pkgs.stably-orca`。

此次移除不涉及 nixpkgs 的 GNOME 屏幕阅读器
`pkgs.orca`，也不删除 Orca 的个人配置、会话、缓存或项目文件。

## 生效方式

在目标主机执行常规 NixOS / Home
Manager 部署后，应用入口和受管理的自启动项才会从当前环境移除。2026-11-10 已终止 Apollo 上残留的 Orca
terminal daemon，并确认没有 `/orca-ide`
进程。尚未执行系统切换，当前 generation 的软件包入口和受管理自启动项仍需部署后才会移除。旧系统 generation 仍可能引用原软件包，本次不执行垃圾回收。

## 验证

通过 `just test` 运行仓库标准求值检查，并对 Apollo、Athena 的配置求值，确认：

- `pkgs` 不再提供 `stably-orca`。
- Home Manager 软件包列表和 XDG 自启动项均不包含 Orca。
- Niri 配置不再包含 `app-id="orca"` 窗口规则。

## 恢复方式

如需恢复，需从移除前的版本恢复专用 overlay、软件包声明、自启动项和窗口规则，并重新验证、部署；不要用
`pkgs.orca` 替代，它是另一个应用。
