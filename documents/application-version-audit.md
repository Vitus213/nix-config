# 应用版本审计

本文记录用户应用的实际安装边界与版本来源。常规包随 `flake.lock`
更新，不再复制一份很快漂移的手工版本表；查询当前声明版本使用文末命令。求值版本不是运行中程序的版本，配置变更须部署后才生效。

## 当前安装与维护边界

| 应用或能力                       | 配置入口与来源                                                | 维护方式                                                            |
| -------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------- |
| VSCode、Cursor、Zed、LibreOffice | `home/linux/gui/base/editors.nix`，主 nixpkgs                 | 跟随主输入；VSCode 的 X11/libsecret 参数保留                        |
| Delta                            | 官方 `delta-nix` input，`overlays/delta` 仅改名为 `delta-zed` | 更新官方 input；保留与 git-delta 的命名隔离                         |
| Catppuccin VSCode 主题           | `catppuccin/nix` 上游配方                                     | 已包含 nodejs-slim 修复，不再复制扩展构建实现                       |
| Zen / Chrome                     | 社区 Zen input / 主 nixpkgs                                   | Zen 是默认浏览器；Chrome 提供 Notion、Linear web app                |
| Telegram                         | `nixpaks.telegram-desktop`                                    | 唯一保留的 NixPak 包装，版本随 nixpkgs                              |
| 微信                             | 主 nixpkgs，`overlays/wechat` 保留启动差异                    | 不再维护整份回移配方；无 NixPak 沙箱                                |
| 飞书                             | 主 nixpkgs，安装点加 portal/PipeWire 参数                     | 保留 XWayland 与屏幕共享适配                                        |
| 腾讯会议                         | 主 nixpkgs + `overlays/wemeet`                                | 保留采集、Mesa/XWayland 与固定二进制主题适配                        |
| Zoom、Sioyek、mpv、imv、Foliate  | 主 nixpkgs，`media.nix` / `misc.nix`                          | Sioyek 保留 xcb 包装；Zoom 不再单独构造包集                         |
| Noctalia                         | 官方固定源码 input，独立 nixpkgs                              | 正式 PAM helper + `pam_service=noctalia-lock`；仅保留工作区样式补丁 |
| Dux Files                        | nixpkgs 包及原生 NixOS 模块                                   | 目录默认应用；不再额外导入项目 flake，ScreenCast portal 保留        |
| Rime Ice                         | nixpkgs `rime-ice`                                            | Linux/Darwin 复用数据包，并显式引入建议 defaults                    |
| Voiceless                        | 独立固定 input 与其验证过的 nixpkgs                           | 保留当前 CUDA 包、daemon、Fcitx 桥和浮层；私有配置不进入 store      |
| Tern                             | `overlays/tern` 的受限官方安装包                              | 用户下载真实产物后更新双平台 hash；保留自启动与工作区规则           |
| FlClash                          | `modules/nixos/desktop/networking/flclash.nix`                | 本地固定 AppImage；不能换成已移除的 nixpkgs alias                   |
| Croc、ccusage                    | nixpkgs 上游配方                                              | 已退役本地 vendor 补丁和四平台二进制表                              |
| OMP、OpenCode、bb、Herdr         | 用户级 Bun/npm/官方安装                                       | 与系统运行时分离；OMP 模型模板与同步行为保持不变                    |

## 已移除的默认安装和无效配置

- 删除误装的 **Notion 窗口管理器**；Notion 笔记仍由 Chrome web app 提供。
- 删除暂停安装的 QQ 沙箱导出、Guix、Flatpak、旧 davfs 与无人消费的 Magpie 本地包；不删除历史数据。
- 删除未激活的 qt6ct、旧 swaybg/wlogout/app2unit/playerctld；壁纸、会话、启动与媒体控制由 Noctalia 提供。
- 截图/标注统一到 Niri/Noctalia，录屏保留 OBS；删除额外录屏器和默认高级 OBS 插件，只保留 PipeWire 音频捕获插件。
- 删除未在受管 profile 中启用的 Mozc/Hangul、重复 FreeRDP CLI 和旧 Insiders 默认关联。
- 保留编辑器、聊天、会议、笔记、Tern、四语言开发与家庭服务。移除 OBS 插件不删除场景文件；旧场景需要的高级源/滤镜须先重新声明对应插件。
- Darwin 旧 Hindsight/Colima 自动启动已退役，服务端保持在 Athena；旧卷及备份保留。
- GTK2 已淘汰，GTK3/4 继续管理；JACK 应用改用 `pw-jack <应用>`，不再通过全局库路径加载兼容层。

需要恢复某项能力时，在原安装组重新声明对应包/插件并部署；不要从备份直接恢复整套已经退役的覆盖或默认配置。

## Google Cloud CLI

共享 TUI 配置 `home/base/tui/dev-tools.nix` 通过 `home.packages` 安装 `pkgs.google-cloud-sdk`，提供
`gcloud`、`bq` 和 `gsutil`。Linux 跟随主 `nixpkgs`，macOS 跟随
`nixpkgs-darwin`；不单独固定版本或启用额外组件。

部署后运行 `gcloud version` 检查安装；需要访问云资源时再执行
`gcloud auth login`。安装不自动登录，凭据留在用户配置目录，不写入 Nix 仓库。更新走对应 nixpkgs
input；移除时删除该包声明并重新部署。

### eric-kvm-dev SSH 连接

`home/base/tui/ssh.nix` 声明 `eric-kvm-dev` 别名，通过 Google IAP 连接 `10.99.0.2:22`，远端用户为
`vitus`，只使用本机 `~/.ssh/id_ed25519`。对应公钥必须已加入远端用户的 `authorized_keys`。

```bash
gcloud auth login vitus.zhang@polygala.ai
ssh eric-kvm-dev
```

隧道显式指定 `boxlite-dev-project`、`us-east5`、`kvm-dev` 网络和 `eric-kvm-dev-ssh`
目标组，因此不需要设置默认 project。Nix 配置中的 `ProxyCommand`
使用同一包集合的 gcloud 绝对路径。部署后可用 `ssh -G eric-kvm-dev` 检查 `proxycommand` 和
`identityfile`；仅手改 `~/.ssh/config` 会在下次 Home Manager 激活时被覆盖。移除别名时删除对应
`programs.ssh.settings` 项并重新部署。

## NixPak 使用边界

当前使用 NixPak 的应用:

- `nixpaks.telegram-desktop`

当前未使用 NixPak 的主要图形应用:

- Zed、Cursor、VSCode、LibreOffice、Delta、飞书
- Zen Browser、Chrome
- WeChat：直接运行上游包及小型启动适配，不使用 NixPak、bubblewrap 或 FHS 沙箱
- FlClash、Noctalia Shell、Voiceless

NixPak 适合继续用于闭源 IM 这类需要限制家目录读写面的应用；编辑器、浏览器、输入法数据、桌面 shell 和系统服务类应用不默认套 NixPak，避免破坏插件、LSP、桌面集成或系统服务行为。

## 检查命令

```bash
# 配置所声明的版本，不等于当前运行进程版本
nix eval --raw .#nixosConfigurations.apollo.pkgs.zed-editor.version
nix eval --raw .#nixosConfigurations.apollo.pkgs.nixpaks.telegram-desktop.name
nix eval --raw .#nixosConfigurations.apollo.pkgs.ccusage.version
nix eval --raw .#darwinConfigurations.artemis.pkgs.croc.version
```

`just test` 同时运行包源策略检查与求值断言。更新 input 的
`just up`、`just upp <input>`、`just up-nix`
不自动提交；检查变更后再自行提交。升级主输入前，先检查 Noctalia、语音模型、腾讯会议等独立固定能力的兼容边界。

## 参考

- Zed Linux 安装文档：<https://zed.dev/docs/linux>
- NixOS Wiki Zed：<https://wiki.nixos.org/wiki/Zed>
