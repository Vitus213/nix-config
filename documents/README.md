# 文档索引

`documents/`
是本仓库唯一的文档目录，记录“当前配置如何工作”：部署流程、组件配置、排障记录和变更历史。各子目录（`hosts/`、`modules/`、`home/`
等）的 `README.md` 只讲目录结构，具体专题都在这里。

> 找不到想要的内容时，先看 [变更记录](./changelog.md)：每条记录都会链接到对应的专题文档。

## 部署与主机

| 文档                                                                       | 内容                                                  |
| -------------------------------------------------------------------------- | ----------------------------------------------------- |
| [全新 NixOS 部署并启用 preservation](./fresh-nixos-preservation-deploy.md) | 新机器从 ISO 到首次切换的完整流程，**新机必读**       |
| [通用 NixOS 桌面 Host](./generic-nixos-host.md)                            | `generic`：不带个人 secrets / preservation 的桌面模板 |
| [hestia（NixOS-WSL）](./hestia-wsl.md)                                     | WSL 终端主机的部署与使用                              |
| [主机共享模块与仓库清理](./host-shared-modules.md)                         | `hosts/_shared/` 的设计与 2026-08 的主机层去重        |
| [LUKS + Btrfs 分区示例](./luks-btrfs-layout.md)                            | 需要整盘加密或 Btrfs 子卷时替换默认 ext4 分区步骤     |
| [rEFInd 引导方案](./refind-boot.md)                                        | `apollo` 上 NixOS 与 Windows 双系统引导               |
| [NixOS 内核策略](./nixos-kernel.md)                                        | 内核版本选择方式                                      |

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

| 文档                                                     | 内容                                           |
| -------------------------------------------------------- | ---------------------------------------------- |
| [Niri 工作区与窗口分配](./niri-workspaces.md)            | 工作区命名、快捷键、窗口规则                   |
| [Niri 显示缩放](./niri-display-scaling.md)               | 多显示器缩放                                   |
| [Noctalia IPC 与服务环境](./noctalia-ipc.md)             | 快捷键 IPC 失效排查、`QT_QPA_PLATFORM` 约束    |
| [Wayland 屏幕共享](./wayland-screen-sharing.md)          | portal、PipeWire 与应用级屏幕共享              |
| [Fcitx5 与 Rime 小鹤双拼](./fcitx5-rime-input-method.md) | 输入法配置、验证与回滚                         |
| [Esc 与 Caps Lock 键位](./keyboard-layout.md)            | NixOS 与 macOS 的键位行为                      |
| [Linux 语音输入](./linux-voice-input.md)                 | Voiceless 语音输入方案                         |
| [Linux 微信、QQ 与飞书](./linux-im-apps.md)              | 安装方式、沙箱边界与屏幕共享                   |
| [Linux 腾讯会议](./tencent-meeting.md)                   | 安装、数据持久化与回滚                         |
| [浏览器与工作协作应用](./work-apps.md)                   | Zen + Chrome；Slack、Notion、Linear 及窗口分配 |
| [Zen Browser](./zen-browser.md)                          | 浏览器安装与配置                               |
| [Orca 桌面应用](./orca.md)                               | StablyAI Orca 的安装方式                       |

## macOS

| 文档                                       | 内容                         |
| ------------------------------------------ | ---------------------------- |
| [AeroSpace 使用指南](./aerospace-usage.md) | 平铺窗口管理器的快捷键与规则 |

## 终端与 AI Agent 工具

| 文档                                                       | 内容                                    |
| ---------------------------------------------------------- | --------------------------------------- |
| [Nushell 与 Zellij 启动链路](./nushell-zellij-startup.md)  | 启动关系与低风险排障方法                |
| [Nushell AI Agent 快捷命令](./nushell-ai-agent-aliases.md) | Agent CLI 的安装与快捷命令              |
| [omp 模型配置管理](./omp-models.md)                        | `models.yml` 的生成、新增 provider 流程 |
| [Hindsight 记忆后端](./hindsight.md)                       | Agent 长期记忆服务的部署                |
| [Herdr Agent 终端运行时](./herdr.md)                       | Herdr 与 Zellij 的关系、手机 SSH 接入   |
| [bb Agent IDE](./bb.md)                                    | 安装来源、更新与回滚                    |

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
