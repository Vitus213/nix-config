# 主机共享配置与仓库清理

本文说明共享系统模块的当前行为，以及 2026-11 清理的退役范围。Apollo 已完成构建和切换，其他主机未部署；不删除运行数据，不改变防火墙、密码、密钥或 Athena 家庭服务。

## 当前主机边界

| 配置                                       | 使用方                      | 当前行为                                        |
| ------------------------------------------ | --------------------------- | ----------------------------------------------- |
| `hosts/_shared/preservation.nix`           | Apollo                      | 将选定系统、用户目录映射到 `/persistent`        |
| `hosts/_shared/nvidia.nix`                 | Apollo、Athena              | NVIDIA 驱动、容器工具与 Sunshine 编码参数       |
| `modules/nixos/base/zram.nix`              | NixOS 基础模块              | 默认启用 zram，相关 sysctl 仅在 zram 开启时声明 |
| `modules/nixos/desktop/virtualisation.nix` | 桌面主机                    | Podman、OCI backend 和一套完整 QEMU             |
| `secrets/nixos.nix`                        | 启用 desktop secrets 的主机 | agenix 运行时文件及 `/etc/agenix` 链接入口      |
| `vars/networking.nix`                      | `modules/base/users.nix`    | SSH alias、known-host 公钥和 Apollo IPv4        |

Generic 默认不导入 NVIDIA、preservation，也不启用个人 secrets。Athena 使用自己的常驻系统与家庭服务配置，不导入 Apollo 的 preservation。

## Preservation 与 secrets

Apollo 当前 `/` 是普通 ext4，`/persistent` 是同一根分区内的目录，没有启动时擦除 root 或 Btrfs
rollback。Preservation 仍保留现有系统状态、SSH host keys、用户 SSH identity、Home Manager
profile 和应用数据映射；它不是本机的临时根文件系统方案。

不再声明 Secure Boot、libvirt、LXC、LXD、QEMU 服务状态、Flatpak，以及已经没有受管应用的 VSCode
Insiders、Antigravity、Mozc、Helix Steel 路径。删除映射声明不会删除 `/persistent` 中的数据。
`~/.var` 继续保留，因为 Telegram Nixpak 仍使用该目录。被 suppression 吞掉的
`systemd-machine-id-commit` 服务覆盖已经删除，已有持久化 machine-id 和 suppressed unit 继续保留。

NixOS 的六个 `/etc/agenix/*` 入口不再用 numeric mode 触发明文复制，而是使用默认 symlink；目标 secret
owner 为 `vitus`、mode 为 `0400`，由 agenix 在运行时生成。OMP 继续使用 `/run/agenix/omp-keys`。

旧 `/etc/agenix` preservation bind mount 有受控迁移：仅 preservation 主机在 `agenix`
activation 完成后、 `etc` activation 前执行；确认挂载目录与 `/persistent/etc/agenix`
是同一个 inode/device 后普通卸载。未知来源或卸载失败会终止激活，没有 force/lazy 卸载或自动回退到持久化复制。历史
`/persistent/etc/agenix` 副本保留，**本次不会擦除，也不会自动收紧历史文件的旧权限**；新文件的 `0400`
仅描述 agenix 运行时文件。迁移及只看元数据的部署后确认见 [Secrets 管理](../secrets/README.md)。

## 图形、压缩内存与虚拟化

NVIDIA 模块保留 open 驱动、电源管理、容器 GPU 和 Sunshine 配置。空 overlay 已删除； `modesetting`
与 fbdev 使用锁定 nixpkgs 的默认规则，删除重复显式设置。

Apollo、Generic 的 `zramSwap.enable = false`
现在同时停止声明 zram 专用 sysctl，避免没有 zram 时仍强制使用 `vm.swappiness = 180`
等参数。其他启用 zram 的主机沿用原参数。

Podman 和 OCI backend 保留，Athena 的 Hindsight 容器继续依赖它们；QEMU 只安装完整
`qemu`，不再同时安装 `qemu_kvm`。无使用方的 `vfio-pci`
无条件加载、libvirt 用户组和旧 Libvirt/LXD/Waydroid 样板已经删除。Hindsight 的 secret 由 activation 阶段准备，不再依赖不存在的
`agenix.service`。

本机 Flatpak 应用清单为空，已移除 Flatpak 服务及系统、用户 Flatpak 目录映射声明；历史数据保留。Telegram
Nixpak 不依赖 Flatpak 服务，其网络、GPU、通知和 portal 权限保持现有设置，见
[Linux 应用沙箱](../hardening/README.md)。打印和定位配置继续保留。

Avahi 使用 `settings.publish`
原生键，继续发布域、地址和用户服务，不改变发现行为。PipeWire 保留 ALSA/PulseAudio/WirePlumber；JACK 通过已安装的
`pw-jack <应用>` 按需启用，不再设置全局 `LD_LIBRARY_PATH`。需 JACK 的旧启动命令应加 `pw-jack`
前缀；回滚可恢复旧 JACK 开关，但会重新引入上游已弃用的全局库路径注入。

## 2026-11 退役范围

- 删除未启用的 `hardening/apparmor`、`hardening/profiles` 和暂停使用的 QQ Nixpak 包装、导出及
  `safeBind`。Telegram 仍由 Nixpak 安装；resolv.conf 绑定、D-Bus `--filter`
  使用上游行为，移除无效 GPU bundle 设置。
- 删除只有注释的 `modules/nixos/base/btrbk.nix`；当前 ext4 主机不启用 btrbk，见
  [btrbk 配置状态](./btrbk.md)。
- 删除整个 Guix 模块与失效的 Guix 子卷说明；不删除 `/gnu`、profile 或其他历史数据。
- 删除没有实际 WebDAV 挂载声明的 `hosts/_shared/netdev-mount.nix`，同步移除 Apollo、Generic 导入。
- `vars/networking.nix`
  只保留实际生成 SSH 配置所需的字段，删除未使用的网关、DNS、IPv6、网卡与 interface 生成器。各主机 NetworkManager/DHCP 配置保持原行为。
- 删除 `templates/bevy` 和已执行完的旧 `documents/plans`
  方案文件。现有四语言开发环境保留，不以删除历史方案文件作为删除开发能力的依据。

## Darwin 与共享入口

`lib/macosSystem.nix` 继续追加共享 overlays，但删除十四项以 `emptyDirectory`
遮盖不兼容包的规则和旧 direnv CGO overlay。 `ncdu` 恢复真实上游包，`gdb`
仅由 Linux 编辑器配置引用。Darwin 保留 `nix.enable = false`，使用已有外部 Lix daemon；删除无效的 Nix
daemon settings/extraOptions，保留自定义 GC。Darwin agenix 数据改用 `0400`，应用直接读取
`/run/agenix`；删除旧 `/etc` alias 过渡和 postActivation chown。

Home Linux GUI 入口继续继承 TUI 入口，再追加 GUI 配置。新增主机时复制硬件差异文件，共享能力通过
`_shared/` 导入，不要恢复失效的整份主机模板。

## Apollo 的 FUSE allow_other

`hosts/olympians-apollo/default.nix` 保留
`programs.fuse.userAllowOther = true`，允许 BoxLite 的 rootless 挂载申请
`allow_other`。该选项只开放申请能力，不会重挂载已有文件系统。部署后 `/etc/fuse.conf` 应包含
`user_allow_other`；撤销时将该选项设为 `false` 后正常部署，相关挂载将不能继续申请此权限。

## 维护与验证

`just up`、`just upp`、`just up-nix` 只更新 flake lock，不再自动 commit，便于先审查变更。
`just test` 执行 nixpkgs policy 检查，并断言 flake evalTests 的 `passed`
为真；CI 使用同一入口。常规部署命令不变，新增主机步骤见 [hosts 说明](../hosts/README.md)。

Home Manager 锁定到
[`b787c48`](https://github.com/nix-community/home-manager/commit/b787c48e2ec57a9d098f5c2721882a3bc1e16f97)，使用正式修复在 GTK2 被标记 broken 后跳过输入法缓存；GTK 配置只维护 GTK3/4，不放宽包检查。GitHub
auth activation 遵循当前 Home Manager 的 `DRY_RUN` 变量，dry-run 不重写凭据文件。

Preservation 锁定到正式兼容修复
[`717cdb8`](https://github.com/nix-community/preservation/commit/717cdb87ac3df05ca6865e1b31ee902e2e2d7952)，移除对已删除
`boot.initrd.systemd.enable` 的引用；当前 NixOS 只提供 systemd initrd，仓库也不再设置该开关。

本轮已通过 `just test`（包源 policy 与求值断言）、四个 NixOS 主机完整 toplevel、Hermes
activation 及 Apollo/Generic ISO
derivation 求值；这不等于完整系统或 ISO 已构建。Noctalia 与腾讯会议 capture 库已构建；Noctalia
CLI、配置检查及本地插件 lint 通过，独立检查配置时有四条未加载插件的警告。capture 两项原生测试和实际预加载通过。Dux/Croc/ccusage/Rime
Ice 的上游包已实现到 store，前三者版本 CLI 已运行，Rime 数据确认提供 `rime_ice_suggestion.yaml`
和小鹤双拼 schema；Apollo 部署后 Dux 已由新包运行，CLI 搜索中文文件通过。生成后的 Nushell 配置已启动；自动进入 Zellij 的交互 PTY、attach、退出保留 shell、四种嵌套排除，以及非交互/无 TTY 分支均通过。Avahi 生成文件保留原发布参数；`pw-jack`
实际设置子进程库路径，系统求值确认不再注入全局 `LD_LIBRARY_PATH`。生成后的 Home
Manager 激活片段在临时目录中覆盖空 token、凭据
`0600`、dry-run、旧受管链接、一次性备份及冲突拒绝。secret 挂载迁移已先用假命令覆盖正常卸载、无挂载、未知来源拒绝和卸载失败。Apollo 已执行真实 secret 迁移：`/etc/agenix`
不再是挂载点，六个入口解析到 `/run/agenix.d/3`，目标均为 `vitus:users 0400`
且用户可读，历史副本保留。Artemis 原生元数据求值确认只保留 `gnupg-agent`、`nix-gc` 两个用户 launchd
agent， `nix.enable=false`，五个 secret 均为
`0400`；检查来自临时快照，没有更新 macOS 正式仓库或配置。Apollo 完整系统及 `home.path`
已构建，并于 2026-11-15 21:40 执行 `switch`：generation 85，运行系统和开机 profile 同为
`96ns5xgjl1qwkv9nj9by3qln171m4dn1`，Home
Manager 激活成功。下载断流通过本次命令关闭 HTTP/2、启用 fallback，并从 Go 镜像获取同 hash
vendor 产物解决；未修改锁定版本或 hash。Noctalia、hypridle、Dux、PipeWire、WirePlumber、portal 均 active；新 Noctalia 与既有 Niri
IPC 可通信，用户 failed unit 为空。11 月 15 日 `switch` 返回 4，原因是当时加载的 NVIDIA 模块
`595.104.02` 与新用户态 `595.112.07` 不匹配。2026-11-16 只读检查确认当前运行内核
`6.18.63`、NVIDIA 模块 `595.112.07`； `nvidia-cdi-generator.service` 的
`Result=success`、`ExecMainStatus=0`，该驱动版本不匹配已解除。新 PAM
helper 已部署但未进行本人错误/正确密码复测。Artemis 完整求值仍因原生依赖下载断流超时；本次没有部署其他主机。

2026-11-16 整理提交前重新运行 `just test`，包源 policy 与求值断言通过（`true`）；变更的 Nix 文件通过
`nixfmt --check`，安装后的 Niri 配置通过 `niri validate`。仓库 Niri 入口依赖部署生成的
`niri-hardware.kdl` 和 `noctalia-shell.kdl`，不能直接作为完整配置单独校验。本轮未升级 flake
inputs、构建或切换系统，也未扩大此前的密码验收与跨主机验证范围。提交前审查另修复两处回归：Darwin
Rime 父目录取消 `force`，备份冲突保护经锁定 Home Manager 脚本冒烟；Apollo/Generic 在
`image.modules.iso.isoImage` 补回 EFI 与 USB 混合引导，最终配置及 builder 两项均为
`true`，两份 derivation 求值成功。未构建完整 ISO 或进行启动测试，详见
[Rime 文件保护](./fcitx5-rime-input-method.md) 与
[ISO 部署说明](./fresh-nixos-preservation-deploy.md#2-在-iso-里准备环境)。

NVIDIA 默认值与 `/etc` 模式依据锁定 nixpkgs
[`d5cc6833999746cffdfe0598f7bc801a57b887a9`](https://github.com/NixOS/nixpkgs/tree/d5cc6833999746cffdfe0598f7bc801a57b887a9/nixos/modules)，secrets
activation 依据锁定
[`agenix 4835b1d`](https://github.com/ryantm/agenix/blob/4835b1dc898959d8547a871ef484930675cb47f1/modules/age.nix)。

## 回滚

回滚应重新加入需要的模块或路径映射声明，再按正常部署流程切换。被移除能力必须有真实消费者，如恢复 btrbk 先有 Btrfs
subvolume，恢复 davfs 先有实际 WebDAV 挂载，恢复 Libvirt 先启用服务。现有
`/persistent`、容器卷和应用目录未被删除；重新加入映射前应确认目标数据，避免空目录遮住已有文件。

Secrets 回滚须同时恢复 `/etc`
copy 声明和旧 preservation 映射，详见 secrets 文档；不要仅重新挂载旧目录，否则会遮住当代运行时链接。其余清理可逐项恢复声明，不需要删除任何运行数据。
