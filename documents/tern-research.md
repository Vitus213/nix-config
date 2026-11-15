# Stencil Tern 安装与配置

本仓库安装的是 [Stencil Tern](https://stencil.so/tern)，下载入口为
<https://build.stencil.so/tern>。版本固定为 **0.9.21 (bde0861)**。 `tern.build` 的同名 coding agent
IDE 是另一个产品；nixpkgs 的 `pkgs.tern` 则是 PostgreSQL 迁移工具，都不用于本配置。

## 打包来源与入口

- `overlays/tern/default.nix`：暴露 `pkgs.tern-stencil`，按平台选择包；命令名为 `tern`。
- `overlays/tern/linux.nix`：基于官方 glibc x86_64 tarball，参考
  [pelikanade/flake](https://github.com/pelikanade/flake/blob/main/modules/packages/tern/default.nix)
  的 `requireFile + autoPatchelfHook + desktopItems`，补齐 ELF interpreter、C++ 运行库、GPU driver
  runpath；动态加载库参考
  [plumj-am/nixos](https://github.com/plumj-am/nixos/blob/master/packages/tern/tern.nix)，包含 Wayland/X11、Vulkan/EGL、WebKitGTK、PipeWire/PulseAudio。包装器提供 git、zenity、gdbus、GIO
  TLS 后端、GSettings schema 与基础 GStreamer 插件。
- `overlays/tern/darwin.nix`：ARM64 DMG，沿用 nixpkgs
  [Raycast](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ra/raycast/package.nix) 的
  `stdenvNoCC + undmg + dontFixup`，完整保留签名 App、动态库和 daemon helper；App 外另提供 CLI
  wrapper。
- `home/base/gui/tern.nix`：共享图形环境安装包；只合并
  `auto_update = false`，设置保留为可写普通文件，其他 GUI 偏好保持不变。Linux 与 Darwin CLI
  wrapper 用 Bash 捕获登录环境。

只支持已取得并验证安装包的 `x86_64-linux`、`aarch64-darwin`。不复制旧社区配方的 Nushell
shim：0.9.21 已内置 Nushell 集成。目前不改变用户登录 shell、默认终端、快捷键或 OMP provider。

## 受限安装包导入

构建服务需要账号权限；由用户登录官网下载，Nix 只接收本地文件，不在表达式中写 cookie、token 或带认证的下载链接。
`requireFile` 的哈希必须匹配下面的文件。原始包不提交到 Git。

| 平台         | 文件                              | SHA-256                                                            |
| ------------ | --------------------------------- | ------------------------------------------------------------------ |
| Linux x86_64 | `Tern-0.9.21-linux-x86_64.tar.gz` | `655cf7fac7ad1aac3153e4d0d9fe4772c147b5bf925d5a0fd10bb9beeb133adf` |
| macOS ARM64  | `Tern-0.9.21-macos-arm64.dmg`     | `9ecc90f95857af7c3f58bf2724ade7e9737c14791bc6fecee39542539df4f594` |

Linux 导入与 GC root：

```sh
source_path=$(nix-store --add-fixed sha256 "$HOME/Downloads/Tern-0.9.21-linux-x86_64.tar.gz")
nix-store --realise "$source_path" --add-root "$HOME/.local/state/tern-nix-source-linux"
```

macOS 将文件名换为 ARM64 DMG，root 名换为 `tern-nix-source-macos`。Artemis 的 SSH 环境可用
`/nix/var/nix/profiles/default/bin/nix-store` 与同目录的 `nix`。必须保留原始包或这个 GC
root；安装输出本身不一定保留原始固定哈希输入。

导入后可单独构建并安装，无需整机 switch：

```sh
nix build --impure --expr 'let f = builtins.getFlake "path:/home/vitus/nix-config"; in f.nixosConfigurations.apollo.pkgs.tern-stencil'
nix profile add ./result
```

Athena 将 `apollo` 换为 `athena`。Artemis 使用
`path:/Users/vitus/nix-config`、`darwinConfigurations.artemis.pkgs.tern-stencil`，其 Lix
2.93.0 对应命令是 `nix profile install ./result`。新文件尚未提交时使用 `path:`，避免 Git
flake 忽略未跟踪文件。后续正常 Home Manager 部署会从同一声明安装。

## 当前部署状态

2026-11-15 已通过 Nix 用户 profile 安装，相关包定义及共享 Home Manager 模块已同步到三台各自的
`~/nix-config`。安装配置已提交并推送；后续增加的登录自启动和工作区规则另行记录在下方。

| 主机    | 安装与启动                                                   | 验证                                               |
| ------- | ------------------------------------------------------------ | -------------------------------------------------- |
| Apollo  | 用户 profile 的 `bin/tern`；应用菜单显示 Tern                | 版本、真实窗口、终端命令输出、OMP 路径及截图       |
| Athena  | 用户 profile 的 `bin/tern`                                   | 版本、真实窗口首帧呈现并接收输入后正常退出         |
| Artemis | 用户 profile；`~/Applications/Tern.app`，`~/.local/bin/tern` | 版本、完整签名校验、真实 AppKit 窗口首帧及输入就绪 |

Athena 安装前已有 0.9.21 的用户级 Tern 和 `tern-remote.service`。现有远程服务仍使用
`~/.local/share/tern/build/tern`，原 daemon/shell 会话保留；本次没有重启服务或迁移正在运行的会话。新登录的
`tern` 已优先解析到 Nix profile。远程服务的独立更新生命周期不由本次 GUI 包声明接管。

Artemis 已注册 LaunchServices，Finder 可打开 `~/Applications/Tern.app`。签名身份为 Can Boluk
(VTLHGQC72S)，上游 DMG 带 notarization ticket。

## 使用与设置

```sh
tern                  # 打开终端工作区
tern ~/nix-config     # 在指定目录打开
tern --version
```

macOS 也可直接从 `~/Applications/Tern.app`
打开。窗口关闭后 daemon 可以继续保留 shell；不要为更新验证运行会终止 session 的 daemon stop。
[官方架构](https://docs.stencil.so/tern/concepts/architecture.md)。

### 登录自启动与工作区 1

- Apollo、Athena：通过 `home/linux/gui/base/xdg/autostart.nix` 登录自启动 Tern；
  `home/linux/gui/niri/conf/windowrules.kdl` 将 `so.stencil.tern` 窗口放入 `1terminal`
  并最大化。两台当前用户的 XDG autostart 条目已安装，无需等待整机 switch。
- Artemis：AeroSpace 已设置登录启动，`after-startup-command` 打开 `~/Applications/Tern.app`；
  `on-window-detected` 将 Tern 平铺到
  `1Terminal`。配置已同步并 reload。实测配置校验及启动命令成功；Tern 进程运行，但本次远程查询中 AeroSpace 未枚举出其窗口，因而 macOS 实际窗口位置尚未验收。未重启或重新登录验证完整登录流程。
- 启动对象是桌面窗口；不新增网络监听，也不重启 Athena 既有 remote service。
- 撤销时移除对应 autostart 项、AeroSpace 启动命令和窗口规则，并清除两台 Linux 的
  `~/.config/autostart/so.stencil.tern.desktop`。

默认 agent 命令为 `omp`，使用已有 OMP 的配置及登录。Tern 另有 Managed
OMP 功能，会自行下载 OMP 并优先放入 pane
PATH；这是独立管理机制，不等于系统已有的 bun 安装。要使用现有 OMP，在 Settings →
Agents 的 OMP 管理项选择 **Stop Managing**，再在 shell 中检查
`command -v omp`。Apollo 本次已执行 Stop Managing；初次隔离试跑遇到的 managed
OMP 下载 EOF 不影响 Nix Tern 包和现有 OMP。未验证真实模型推理或 TSP 会话。

设置目录见[官方目录说明](https://docs.stencil.so/tern/concepts/packages.md#directories)：

- Linux：`~/.config/tern/settings.json`。
- macOS：`~/Library/Application Support/Tern/settings.json`。
- 本次三台均写入 `auto_update: false`。更新交给 Nix；不要在只读 store 上应用内自更新。

## 更新与回滚

登录官网下载新版本，核验包、版本与依赖后更新两个 derivation 的版本/hash，重新导入并构建。不要复用其他版本的哈希，也不要将账号信息写入 store。关闭旧窗口不会自动迁移所有运行中的 daemon；先保存工作，再根据上游的
`tern restart` 使用说明安排切换。

仅回滚本次定向安装：从用户 profile 移除
`tern-stencil`；Artemis 另移除本次创建的两个用户链接。若要永久移除，在共享模块中取消包声明后正常部署；保留用户配置和会话数据，除非明确要清空。

## 验证范围

Linux、macOS 实际构建成功；三台 `tern --version` 均为
`0.9.21 (bde0861)`。三台真实窗口首帧检查成功，Apollo 通过控制端点运行终端命令、读取成功标记并截图。
`nix eval path:/home/vitus/nix-config#evalTests --show-trace` 返回
`true`；Nix 格式检查通过。未验证浏览器媒体、屏幕共享、远程配对、模型请求或全部内置 pane 功能。
