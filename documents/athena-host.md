# athena（开发机 + 家庭服务，niri 桌面）

`athena`
是一台实体机 NixOS，定位是开发机，同时承载原 j1900 上的家庭服务。平时通过 SSH 远程使用；桌面与 apollo 相同（niri +
noctalia），需要时直接接显示器。

硬件：微星 MS-H610M 666 WIFI6、i5-12400F（无核显）、RTX 4060、32G 内存、Intel CNVi WiFi
/ 蓝牙（`8086:7af0`）、Realtek RTL8111 有线网卡。与 Windows 双系统，共用一块 NVMe：

| 分区             | 用途                                  | 挂载    |
| ---------------- | ------------------------------------- | ------- |
| `nvme0n1p1`      | Windows 原有 ESP（300M，`E394-2F85`） | `/boot` |
| `nvme0n1p3`/`p4` | Windows                               | —       |
| `nvme0n1p5`      | NixOS 根分区（ext4，`fdba9ad4-…`）    | `/`     |

入口：

- `outputs/x86_64-linux/src/olympians-athena.nix`：与 apollo 相同的模块组合（`secrets/nixos.nix`、
  `modules/nixos/desktop.nix`、`hardening/{nixpaks,bwraps}`、niri、`home/linux/gui.nix`）
- `hosts/olympians-athena/default.nix`：引导、网络、禁止睡眠、开发工具
- `hosts/olympians-athena/hardware-configuration.nix`：`nixos-generate-config` 结果，按 UUID 挂载
- `hosts/olympians-athena/services.nix`：家庭服务
- `hosts/olympians-athena/home.nix`：NVIDIA、X11 兼容、niri 硬件文件
- `hosts/olympians-athena/niri-hardware.kdl`：只声明命名工作区，不固定 output

## 当前行为

- 引导：systemd-boot，`canTouchEfiVariables = true`，装在 Windows 原有 ESP 上，菜单自动包含 Windows
  Boot Manager。ESP 只有 300M（每代内核 + initrd 约 57M），`configurationLimit = 3`
- `time.hardwareClockInLocalTime = true`，与 Windows 的 RTC 本地时间一致
- 内核 `linuxPackages_6_18`（LTS）；NVIDIA 走 `hosts/_shared/nvidia.nix`（开源内核模块）
- 网络：NetworkManager 管理有线与 WiFi，`nmcli dev wifi connect <SSID> --ask`
  或 noctalia 面板连接；WiFi 固件来自 `hardware.enableRedistributableFirmware`
- 地址：有线 `enp2s0`（RTL8111，千兆）`192.168.100.11`，WiFi `wlo1` `192.168.100.12`
  作备用，都由主路由 Q30（`192.168.100.1`，ImmortalWrt）的 DHCP 固定租约绑定 MAC：uci `dhcp` 里
  `name='athena'`（有线 `00:e2:69:8a:78:ce`）与 `name='athena-wifi'`（WiFi
  `a0:d3:65:67:b0:29`）；改前备份
  `/etc/config/dhcp.bak-20261027-athena`、`/etc/config/dhcp.bak-20261027-athena-wired`。主机仍走 DHCP，不在 NixOS 里写静态 IP；NetworkManager 默认路由有线 metric
  100、WiFi 600，拔网线后自动走 WiFi。SSH 别名 `ssh athena` （`home/base/tui/ssh.nix`）指向 `.11`
- 网络唤醒：`networking.interfaces.enp2s0.wakeOnLan.enable = true`，udev `.link` 设
  `WakeOnLan=magic` （`ethtool enp2s0` 显示
  `Wake-on: g`，重启后保持）。只对有线网卡有效，WiFi 的 WoWLAN 只能从挂起唤醒，而挂起已禁用。BIOS（MSI
  Click BIOS）需 `Settings → Advanced → Wake Up Event Setup → Resume By PCI-E Device = Enabled`、
  `Settings → Advanced → Power Management Setup → ErP Ready = Disabled`（ErP 开启时关机后网卡不供电）。唤醒：任一主机执行
  `wake-athena`（`home/base/core/shells/default.nix` 的别名，向 `192.168.100.255`
  发魔术包，需在同一局域网），关机状态约 35 秒后可 ping 通
- 蓝牙：`modules/nixos/desktop/peripherals.nix` 的 `hardware.bluetooth` + blueman
- 禁止睡眠：`systemd.targets.{sleep,suspend,hibernate,hybrid-sleep}.enable = false`。原装的 GNOME/GDM 空闲约 20 分钟会自动挂起，导致 SSH 断开
- 桌面：greetd 自动登录 `vitus` 进入 niri；不接显示器时 niri 无输出照常运行
- secrets：agenix identity 为
  `/etc/ssh/ssh_host_ed25519_key`（`root@nixos`，安装时生成），已加入 my-secrets 的 `athena`
  recipient；`/etc/agenix/*` 与 apollo 相同
- 用户：`users.mutableUsers = false`，`vitus` 密码来自 `vars/default.nix` 的
  `initialHashedPassword`（与 apollo 相同），安装时设的临时密码失效；root 只允许公钥登录
- Tailscale：desktop 模块会启用 `tailscaled`，但 athena **不加入 tailnet**，只在局域网内访问
- `system.stateVersion = "26.05"`（`nixos-install` 时的版本，不要改）

## 服务

版本以当前 `flake.lock` 中的 nixpkgs（`55bfb4d7`，2026-10-14，NixOS 26.11）为准。

| 服务        | 版本                         | 地址                                                                  | 数据                                                                 |
| ----------- | ---------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------- |
| SSH         | OpenSSH                      | `:22`，root 只允许公钥                                                | —                                                                    |
| Tailscale   | 1.104.1                      | 服务在运行，不登录、不加入 tailnet                                    | —                                                                    |
| Jellyfin    | 12.2                         | `http://athena:8096`                                                  | `/var/lib/jellyfin`；媒体 `/srv/media/{movies,tv,music}`             |
| Immich      | 3.3.1（含机器学习）          | `http://athena:2283`                                                  | `/var/lib/immich`；PostgreSQL 18.6 + Redis 由模块管理                |
| Uptime Kuma | 2.5.6                        | `http://athena:3001`                                                  | `/var/lib/uptime-kuma`                                               |
| qBittorrent | 5.2.4（`qbittorrent-nox`）   | WebUI `http://athena:8080`；BT 端口 6881                              | `/var/lib/qBittorrent`；下载到 `/srv/media/downloads/qbittorrent`    |
| aria2       | 1.37.0                       | RPC `http://athena:6800/jsonrpc`；BT 端口 6888                        | `/var/lib/aria2`；下载到 `/srv/media/downloads/aria2`                |
| AriaNg      | 1.3.15（nginx 静态页）       | `http://athena:6880`                                                  | —                                                                    |
| Vaultwarden | 1.37.4（web vault 2026.7.0） | `https://vault.vituss.me`（Cloudflare Tunnel）；本机 `127.0.0.1:8222` | `/var/lib/vaultwarden`；备份 `/var/backup/vaultwarden`（每日 23:00） |
| cloudflared | 2026.10.0                    | 隧道 `athena`（`929d36f9-1bfd-4013-a762-2eb4e33c6583`），只出站       | 凭据 agenix `cloudflared-athena.json`                                |

- qBittorrent：没有用模块的 `serverConfig`，因为它每次启动都会整份覆盖
  `qBittorrent.conf`，WebUI 里改的密码会丢。改为 `preStart`
  只在配置文件不存在时写入种子配置（接受法律声明、保存路径、tracker 列表
  `https://cf.trackerslist.com/best.txt`、WebUI 监听 `*`），之后的修改都留在原文件里。
- aria2：RPC secret 不能进 nix store。`aria2-secret.service` 在首次启动时生成随机值到
  `/var/lib/aria2-secret/rpc-secret`（仅 root 可读），`aria2.service` 依赖它。
- Immich 机器学习默认开启（人脸、智能搜索），内存不够时把 `services.immich.machine-learning.enable`
  改为 `false`。
- Vaultwarden（Bitwarden 兼容服务端）：
  - 只监听 `127.0.0.1:8222`，对外只走 Cloudflare Tunnel（本地管理型，ingress 写在
    `services.nix`）。DNS `vault.vituss.me` 是 CNAME `<隧道 ID>.cfargotunnel.com`（已开代理）
  - `SIGNUPS_ALLOWED = false`，账号只能由管理员邀请；未配 SMTP，被邀请邮箱直接在网页注册即可
  - `/admin` 在隧道入口返回 404（模块每个 hostname 只能写一条 ingress，所以这条专拦
    `^/admin`，其余落到
    `default`）。管理页经 SSH 转发：`ssh -L 8222:127.0.0.1:8222 root@192.168.100.11` 后开
    `http://localhost:8222/admin`；管理口令明文在 my-secrets `vaultwarden-admin-password.age`
    （只有 master_key 与 apollo `~/.ssh/id_ed25519`
    能解），athena 上只有 Argon2 哈希（`vaultwarden-env.age`）
  - `IP_HEADER = CF-Connecting-IP`：日志与登录限流按真实客户端 IP
  - 隧道协议用默认
    `auto`：cloudflared 预检 QUIC（7844/udp）通、HTTP/2（7844/tcp）握手超时。隧道出站经 Q30
    OpenClash（`MATCH → 自动选择`），节点不稳时会反复重连、外网报 530（Cloudflare 1033）
  - 异地备份：apollo 用户级 timer `vaultwarden-backup-pull`（每日 23:30，`Persistent`）拉到
    `~/backups/vaultwarden/<日期>/`，保留 30 天（`hosts/olympians-apollo/home.nix`）
  - `vituss.me` 2026-11-02 到期；换域名要改 `DOMAIN`、ingress hostname 与 Cloudflare
    CNAME，换之前不要注册通行密钥 / WebAuthn（绑定域名）

## 部署

athena 先用官方安装盘装了带 GNOME 的默认 NixOS，2026-10-27 从 apollo 切到本仓库配置（generation
3；generation 1/2 是安装盘系统）。前置条件（已完成）：

- apollo 的 `~/.ssh/id_ed25519.pub` 写入 athena 的 `/root/.ssh/authorized_keys` 与
  `/home/vitus/.ssh/authorized_keys`；切换后 `vitus` 的公钥由 `vars/default.nix` 管理，root 的
  `~/.ssh/authorized_keys` 文件仍然有效
- athena 的 host key 公钥加入 my-secrets 并重新加密全部 `.age`，本仓库 `flake.lock` 已更新到对应提交

从 apollo 部署（新文件需已 `git add`）：

```bash
cd ~/nix-config
nixos-rebuild switch --flake .#athena --target-host root@192.168.100.11
```

首次切换注意：

- 安装盘的 GNOME/GDM 空闲约 20 分钟会挂起，复制闭包期间会断线。切换前先在 athena 上挡住睡眠（命令用绝对路径，
  `systemd-run` 的 PATH 里没有 `sleep`；`systemctl mask --runtime` 对 NixOS 的 `/etc` 单元无效）：

  ```bash
  systemd-run --unit=deploy-inhibit /run/current-system/sw/bin/systemd-inhibit \
    --what=sleep:idle --mode=block --why=deploy /run/current-system/sw/bin/sleep 7200
  ```

- 切换时内核仍是安装盘的 7.3，`nvidia-container-toolkit-cdi-generator` 报
  `Driver Not Loaded`、GNOME 会话里的用户 portal 启动失败，都属预期；随后重启一次进入 6.18 +
  NVIDIA 驱动即恢复。
- Herdr 不由 Nix 安装，需要放到 `~/.local/bin/herdr`，否则 `herdr.service` 会反复报
  `No such file or directory`。athena 没有代理，官方安装脚本从 GitHub
  releases 下载会超时，当前是从 apollo `scp` 同版本静态二进制（0.9.5）；之后用 `herdr update`
  自管理，见 [Herdr](./herdr.md)。

在 athena 本机构建：仓库放在 `~/nix-config`（`niri-hardware.kdl`
通过 out-of-store 符号链接指向这里），
`sudo nixos-rebuild switch --flake ~/nix-config#athena`。私有 input `mysecrets` 依赖
`/etc/agenix/nix-access-tokens` 里的 GitHub token，首次部署后才可用。

## 首次开机后

1. qBittorrent 首次没有密码，临时密码在 `journalctl -u qbittorrent` 里；登录 WebUI 后改密码
2. aria2 secret：`sudo cat /var/lib/aria2-secret/rpc-secret`，填到 AriaNg「AriaNg 设置 → RPC」
3. Jellyfin、Immich、Uptime Kuma 在网页里完成初始化向导（创建管理员）
4. Vaultwarden：管理页邀请账号后，在 `https://vault.vituss.me` 注册，立即开启 TOTP 两步验证

## 从 j1900 迁移时注意

- 版本：j1900 上 Docker 版 Immich 是 `v3.3.5`、Jellyfin
  `12.3`，都比当前 nixpkgs 新（`3.3.1`、`12.2`）。直接搬数据库或配置等于降级，Immich 的数据库迁移可能不兼容。迁移前先把 nixpkgs 更新到不低于 j1900 的版本，或在 Immich 里重新导入照片
- 出口分流：j1900 上 qBittorrent /
  aria2 用 macvlan 独立 IP（`.9`、`.10`），路由器按源 IP 分流（qB 直连、aria2 走「⬇️下载」分组）。athena 上两者共用主机 IP，原规则不再生效，迁移时要在路由器上按 athena 的 IP 重新规划
- 两台同时开机时，j1900 上的服务继续占用原 IP（`.3`、`.9`、`.10`），athena 用 `.11`，不冲突

## 回滚

- 系统层：systemd-boot 菜单选上一代，或
  `sudo nixos-rebuild switch --rollback`；安装盘的 GNOME 系统是第一代，在 `configurationLimit`
  清理前也能选回
- secrets：my-secrets 回退提交 `4a10da3`（新增 athena recipient 并 rekey），再
  `nix flake update mysecrets`
- Vaultwarden：回滚系统后 `/var/lib/vaultwarden`、`/var/backup/vaultwarden`
  保留，彻底清除需手动删；Cloudflare 侧删隧道 `athena` 与 CNAME `vault.vituss.me`
- 仓库：删除 `hosts/olympians-athena/`、`outputs/x86_64-linux/src/olympians-athena.nix` 和测试里的
  `athena` 条目
