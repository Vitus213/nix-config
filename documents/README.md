# 文档索引

`documents/`
是本仓库唯一的文档目录，记录“当前配置如何工作”：部署流程、组件配置、排障记录和变更历史。各子目录（`hosts/`、`modules/`、`home/`
等）的 `README.md` 只讲目录结构，具体专题都在这里。

> 找不到想要的内容时，先看 [变更记录](./changelog.md)：每条记录都会链接到对应的专题文档。

## 部署与主机

| 文档                                                                       | 内容                                                    |
| -------------------------------------------------------------------------- | ------------------------------------------------------- |
| [全新 NixOS 部署并启用 preservation](./fresh-nixos-preservation-deploy.md) | 新机器从 ISO 到首次切换的完整流程，**新机必读**         |
| [通用 NixOS 桌面 Host](./generic-nixos-host.md)                            | `generic`：不带个人 secrets / preservation 的桌面模板   |
| [athena（开发机 + 家庭服务）](./athena-host.md)                            | 与 Windows 双系统的部署、secrets、服务清单与 j1900 迁移 |
| [hestia（NixOS-WSL）](./hestia-wsl.md)                                     | WSL 终端主机的部署与使用                                |
| [主机共享模块与仓库清理](./host-shared-modules.md)                         | `hosts/_shared/` 的设计与 2026-08 的主机层去重          |
| [LUKS + Btrfs 分区示例](./luks-btrfs-layout.md)                            | 需要整盘加密或 Btrfs 子卷时替换默认 ext4 分区步骤       |
| [rEFInd 引导方案](./refind-boot.md)                                        | `apollo` 上 NixOS 与 Windows 双系统引导                 |
| [NixOS 内核策略](./nixos-kernel.md)                                        | 内核版本选择方式                                        |

| [hermes（Ubuntu WSL）](./hermes-wsl.md) | Ubuntu 24.04 独立 Home Manager、用户 secrets 与验证 |

## 系统维护

| 文档                                                         | 内容                                      |
| ------------------------------------------------------------ | ----------------------------------------- |
| [nix 自动垃圾回收策略](./nix-gc.md)                          | NixOS / nix-darwin 两端一致的 gc 策略     |
| [btrbk 配置状态](./btrbk.md)                                 | Btrfs 快照与备份                          |
| [应用版本审计](./application-version-audit.md)               | 主要应用的版本来源与覆盖情况              |
| [Croc build 修复](./croc-build-fix.md)                       | `overlays/croc` 的临时覆盖原因与移除条件  |
| [Homebrew TUNA 镜像排障](./homebrew-tuna-troubleshooting.md) | macOS 上 Homebrew 仍访问 `ghcr.io` 的排障 |

## 网络与安全

| 文档                                             | 内容                          |
| ------------------------------------------------ | ----------------------------- |
| [网络与代理策略](./network-proxy.md)             | 软路由透明代理与本机出网模型  |
| [Homelab SSH Key](./homelab-ssh-key-romantic.md) | `ssh-key-romantic` 的管理方式 |
| [Noctalia 锁屏解锁延迟修复](./lockscreen-pam.md) | PAM 配置与锁屏延迟问题        |

## Linux 桌面（Niri + Noctalia）

| 文档                                                                  | 内容                                                   |
| --------------------------------------------------------------------- | ------------------------------------------------------ |
| [Noctalia v5 迁移](./noctalia-v5.md)                                  | 固定 5.5.0、TOML/插件所有权、备份、test 验收与完整回滚 |
| [Niri 工作区与窗口分配](./niri-workspaces.md)                         | 工作区、快捷键、窗口规则、kitty 与 Dux Files           |
| [Niri 显示缩放](./niri-display-scaling.md)                            | 多显示器缩放                                           |
| [Linux 中文字体选型调研](./linux-font-selection-research.md)          | 文楷/等宽分工、社区样本与应用字体回退                  |
| [Noctalia IPC 与服务环境](./noctalia-ipc.md)                          | v5 命令、notify 服务排序、应用隔离与覆盖层诊断         |
| [Noctalia 工作区状态](./noctalia-workspace-urgent.md)                 | 主色聚焦、低强调占用、urgent 红点与 hover 描边         |
| [工作区高亮官方逻辑调研](./workspace-highlight-official-research.md)  | 2026-11-10 v4 历史：状态链路、urgent 聚合与清除        |
| [工作区高亮社区方案调研](./workspace-highlight-community-research.md) | 2026-11-10 v4/Waybar 与社区样本、呈现规则              |
| [Noctalia 系统监控](./noctalia-system-monitor.md)                     | v5 六项监控、根路径 `/`、负载插件与阈值                |
| [Wayland 屏幕共享](./wayland-screen-sharing.md)                       | portal、PipeWire 与应用级屏幕共享                      |
| [Fcitx5 与 Rime 小鹤双拼](./fcitx5-rime-input-method.md)              | 输入法配置、验证与回滚                                 |
| [Esc 与 Caps Lock 键位](./keyboard-layout.md)                         | NixOS 与 macOS 的键位行为                              |
| [Linux 语音输入](./linux-voice-input.md)                              | Voiceless 语音输入方案                                 |
| [Linux 微信、QQ 与飞书](./linux-im-apps.md)                           | 安装方式、沙箱边界与屏幕共享                           |
| [微信截图剪贴板调研](./wechat-image-clipboard-research.md)            | Wayland/xcb 对照、版本证据与验收边界                   |
| [Linux 腾讯会议](./tencent-meeting.md)                                | 启动、portal/DMA-BUF 共享、原生主题与录制边界          |
| [浏览器与工作协作应用](./work-apps.md)                                | Zen + Chrome；Slack、Notion、Linear 及窗口分配         |
| [Zen Browser](./zen-browser.md)                                       | 浏览器安装与配置                                       |
| [Orca 移除说明](./orca.md)                                            | 移除范围、生效方式与数据保留                           |

## macOS

| 文档                                       | 内容                         |
| ------------------------------------------ | ---------------------------- |
| [AeroSpace 使用指南](./aerospace-usage.md) | 平铺窗口管理器的快捷键与规则 |

## 终端与 AI Agent 工具

| 文档                                                             | 内容                                                   |
| ---------------------------------------------------------------- | ------------------------------------------------------ |
| [Go、Rust、Java、Python 开发环境](./development-environments.md) | Apollo、Athena 的工具链、PATH、虚拟环境与部署          |
| [Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)        | 启动关系与低风险排障方法                               |
| [Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md)       | Agent CLI 的安装与快捷命令                             |
| [omp 模型配置管理](./omp-models.md)                              | `models.yml` 的生成、新增 provider 流程                |
| [OMP provider 变更技能](../.agents/skills/omp-provider/SKILL.md) | 新增通道、my-secrets、增量同步、OAuth 保留与新会话验收 |
| [Magpie 共享模型网关](./magpie.md)                               | J1900 单实例、客户端接入、Web/TUI 与凭据边界           |
| [Hindsight 记忆后端](./hindsight.md)                             | Agent 长期记忆服务的部署                               |
| [Herdr Agent 终端运行时](./herdr.md)                             | Herdr 与 Zellij 的关系、radar 侧边栏、手机 SSH 接入    |
| [bb Agent IDE](./bb.md)                                          | 安装来源、更新与回滚                                   |
| [Delta agent 协作环境](./delta.md)                               | Zed 团队 Delta 的安装、命名冲突、更新与回滚            |
| [Tern 同名项目与安装调查](./tern-research.md)                    | tern.build CLI 分发与 Stencil Tern 的区别              |
| [AI Agent 用量统计与 WakaTime](./agent-usage.md)                 | profile 用量卡片、ccusage 口径、WakaTime key           |

## 历史与计划

| 文档                                                                                   | 内容                               |
| -------------------------------------------------------------------------------------- | ---------------------------------- |
| [变更记录](./changelog.md)                                                             | 所有配置变更的主线索引，按时间倒序 |
| [plans/2026-07-04 统一 nixpkgs unstable](./plans/2026-07-04-unify-nixpkgs-unstable.md) | 已执行的重构计划，留作背景参考     |

## 写文档的约定

完整规则见根目录 [AGENTS.md](../AGENTS.md) 第 6 节，要点：

- 每个专题一个文件，文件名用小写英文 + 连字符，写**当前**行为，失效描述直接删掉。
- 每次配置变更都在 [changelog.md](./changelog.md) 顶部追加一条，并链接到专题文档。
- 新增专题文档后，把它加进本索引对应分类。
