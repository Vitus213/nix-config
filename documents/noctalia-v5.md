# Noctalia 5.5.0 迁移、配置与恢复

## 当前实施状态（2026-11-13）

apollo 已从 Noctalia Shell 4.7.7 迁移到原生 5.5.0，并完成包含挂载顺序修正的系统 `switch`。Home
Manager 激活成功，`noctalia.service` 与 hypridle 正常运行，活动 Niri 调用已迁为
`noctalia msg`。启动器、工作区、通知、剪贴板、TOTP、番茄钟和托盘已完成下文列出的桌面检查。

首次持久化挂载遮挡插件链接的问题已恢复，两个目录的挂载依赖已加载。用户完成真实错误/正确密码验收，日志确认错误密码被拒绝，随后正确密码解锁。11:18 核对
`/run/current-system` 与 `/nix/var/nix/profiles/system`，两者均指向同一修正版。

Athena 现已完成原生 5.5.0
`switch`；generic 仍仅求值。实际 preservation 只有 Apollo 启用；主 nixpkgs、Niri
26.04 及原有 22 个 input 的依赖闭包未变。

Athena 运行系统与开机 profile 均为
`/nix/store/9w5afbznxzn659zds23jcmdrzpcdgr90-nixos-system-athena-26.11.20261014.55bfb4d`。Home
Manager 成功，Noctalia、hypridle、Dux 均 active、`NRestarts=0`；完整配置校验通过，TOTP/load 与固定番茄钟已加载，launcher/番茄钟 IPC 均成功。切换前的主工作树、旧 Shell
config/cache 和模型配置私密备份在 `/home/vitus/nixcfg-before-deploy.MsKo3z`。

Athena 的 Niri 会话此前已锁定；停止旧 Shell 后合成器保留锁定底色，最初截图不能作桌面通过依据。新版执行
`noctalia msg session lock` 后已接管锁屏，截图确认壁纸、时钟和密码输入框正常，IPC 返回
`locked=true`，保持原有锁定边界。尚未在 Athena 输入错误/正确密码、验收解锁后桌面、重新登录或重启；Apollo 的验收不能代替这些检查。

## 固定版本与两个补丁

- `flake.nix` 的 `noctalia` input 固定
  `c2573248a89470383e41b8e1ac432424691cbc1f`（5.5.0），保留上游自己的 nixpkgs
  `f9a75f41be3a74eab55d3a7679d34ad6cc0da977`，不 follows 主输入。
- `noctalia-plugins` 是非 flake input，固定 community-plugins
  `33d7ba696a6644016ae3c0706c0b5fcf066e42e8`。
- `overlays/noctalia/default.nix` 从官方 `packages.<system>.default` 派生 `pkgs.noctalia`，只追加
  `dedicated-pam.patch` 和
  `workspace-states.patch`。仅支持 x86_64-linux/aarch64-linux，其他平台不求值此包。
- PAM 补丁绑定
  `noctalia-lock`；工作区补丁只改变 Regular 模式，采用主色焦点、占用低强调、独立 urgent 红点和 hover 描边。详见
  [PAM](./lockscreen-pam.md)、[工作区状态](./noctalia-workspace-urgent.md)。

旧 QML urgency 刷新 overlay 已移除；没有旧可执行命令、服务或插件 IPC 兼容别名。`noctalia-shell.kdl`
文件名按原有 include 保留，其内容在切换时迁移。

## 配置与运行数据的所有权

v4 JSON 到 v5 TOML 是手动语义映射，上游自动迁移仅处理旧 TOML 键，不提供 v4 JSON 导入。

| 入口                                              | 所有者与用途                                                              |
| ------------------------------------------------- | ------------------------------------------------------------------------- |
| `home/linux/gui/base/noctalia/config/config.toml` | 仓库基础层；按文件链接到 `~/.config/noctalia/config.toml`                 |
| `~/.config/noctalia/plugins.toml`                 | Nix 生成固定插件源、enabled 列表与 `auto_update="none"`                   |
| `~/.config/noctalia/scripts/totp`                 | 链接到原有脚本，不重写验证码计算                                          |
| `~/.local/share/noctalia/plugins/desktop`         | 链接到仓库本地 Luau 代码，运行数据另存                                    |
| `~/.local/state/noctalia/settings.toml`           | GUI / IPC 写入的覆盖层，最后加载并覆盖基础层                              |
| `~/.local/state/noctalia/state.toml`              | picker 等内部状态；首次合并 `wallpaper_panel.flatten=true`、`sort="name"` |
| `~/.cache/noctalia`                               | 缓存；旧通知/剪贴板数据仅备份，不声称导入新版加密格式                     |
| `~/.config/totp/secrets.conf`                     | 原 agenix 链接，密钥不进入仓库或迁移日志                                  |

首次切换把已有 v5 `settings.toml` 移入私有备份，其他 state/data 保留。后续 activation 不自动清除 GUI
override。仓库值未生效时先检查覆盖层，不要删除全部运行数据。

Home Manager 的 `migrateNoctaliaConfig` 在 `linkGeneration` 前只 unlink 解析到本仓库旧 `config/`
的受管目录链接。真实目录原样保留；指向其他目标的目录链接会中止激活。新版 `~/.config/noctalia`
是实际目录，不再链接整个仓库配置目录。

`hosts/_shared/preservation.nix` 保留 `.cache/noctalia`，新增
`.local/state/noctalia`、`.local/share/noctalia`，权限 `0700`。激活前须把已有数据合并到
`/persistent/home/vitus/` 对应目录，避免空挂载遮挡数据。generic 不启用 preservation；不改变 GNOME
Keyring 保存策略。

Home Manager 单元增加两个运行目录的 `RequiresMountsFor`，确保挂载先于激活。首次 `test` 曾在 Home
Manager 创建本地插件链接后才挂载 data，导致链接被遮挡；已在持久化目录恢复链接，并确认 TOTP/load 实际加载。11:12 激活修正版后，实际单元已包含 state/data 两个目录依赖，Home
Manager `Result=success`、`ExecMainStatus=0`。

## 保留的桌面行为与原生边界

顶栏顺序保持：左侧 launcher、clock、CPU/load/RAM/RX/TX/disk、活动窗口、媒体；中间数字工作区；右侧通知、电池、音量、亮度、TOTP、番茄钟、托盘、控制中心。监控六项共用 capsule，磁盘路径
`/`，详见 [系统监控](./noctalia-system-monitor.md)。

壁纸目录仍为 `/home/vitus/Pictures/Wallpapers`，基础图片
`dome.jpg`，自动换图关闭、递归浏览开启，配色来自壁纸。浮动面板采用原生 soft=0.8。eDP-1 的时钟、媒体、天气组件只在该输出存在时显示；不迁到 DP-1。桌面和锁屏布局采用 v5 原生组件。

`noctalia.service` 使用
`Type=notify`、`After=niri.service`、`Before=graphical-session.target`、`PartOf=graphical-session.target`、`WantedBy=niri.service`，前台运行。只显式设置
`TERMINAL=kitty`，不能带 `-e`；全局 Qt / qt6ct 配置保留。`launch_apps_as_systemd_services=true`
将启动器应用放入独立 transient user
service。已实际启动 kitty 内的心跳任务，重启 Shell 后同一窗口与任务继续运行。

hypridle 独占空闲策略：3 分钟键盘背光、20 分钟锁屏、20 分 30 秒关闭屏幕。原生 idle 三项禁用。`noctalia msg session lock`
立即锁屏，`grace_period_seconds=0`；菜单倒计时保留 10 秒，休眠使用原生命令动作
`systemctl hibernate`。控制中心、通知时长与低优先级历史规则采用 v5 原生行为。

Niri 快捷键的新命令清单见
[IPC](./noctalia-ipc.md)。截图继续使用 Niri，保留现有录屏工具，不为迁移启用录屏插件。

## 本地 TOTP、负载与社区番茄钟

`vitus/desktop` 只有 `totp` 和 `load` 两个 bar entry，manifest API 24。本地 TOTP 每秒 direct
argv 调用原脚本，失败清除旧码；文字按 UTF-8 字符数限制为水平 16、竖向 12，截断服务名且保留完整六位码。完整名称和操作说明保留在 tooltip。左键复制、中键选择并复制、右键切换；中键释放默认 settings 动作，菜单以 detached 方式运行，不受捕获输出的 5 秒超时限制。

```bash
noctalia msg plugin vitus/desktop:totp focused refresh
noctalia msg plugin vitus/desktop:totp focused copy
noctalia msg plugin vitus/desktop:totp focused select-copy
noctalia msg plugin vitus/desktop:totp focused switch
```

`focused` 避免多屏重复执行。`load` 每 2 秒读取 Shell 现有
`systemStats().loadAvg`，不新建进程或采样器。

番茄钟固定 `thepunkoff/pomodoro` 1.4.0 / API 22，使用整份固定 community input 作为 path
source，关闭自动更新。work/short/long/sessions 为 25/5/15/4，不自动开始下一阶段。闹铃使用 Noctalia
Sound API，bypass=false；首位通知过滤器禁止 Pomodoro 通知音，避免与闹铃叠加。manifest 要求的
`ffplay` 由三台主机现有 `ffmpeg-full` 提供。

```bash
noctalia msg panel-toggle thepunkoff/pomodoro:panel
noctalia msg plugin thepunkoff/pomodoro:pomodoro all start
noctalia msg plugin thepunkoff/pomodoro:pomodoro all pause
noctalia msg plugin thepunkoff/pomodoro:pomodoro all skip
noctalia msg plugin thepunkoff/pomodoro:pomodoro all reset
noctalia msg plugin thepunkoff/pomodoro:pomodoro all reset-all
```

旧正计时、自定义累计统计和 stopAlarm 不迁移。旧 `settings.json` 完整私有备份，初始快照为
`totalTrackedSeconds=136533`、`totalTrackedHours=37`、`countdownDurationMinutes=180`；实际切换使用停止旧 Shell 后的最终快照，不伪造新版历史。

## 备份与本机 test 切换

本轮私有备份为 `/home/vitus/tmp/noctalia-v5-20261113-021311`，权限
`0700`，已确认位于持久化分区。`initial/` 包含仓库快照、原有 staged/unstaged patch、解引用的 v4
config/cache、TOTP current_index；不读取生产 secrets。旧系统、旧包、旧 HM
generation 以及新系统保留 GC root，验收前不 GC。

首次失败的快照另存为 `attempt-1-final/`，当时的 v5 数据另存到
`v5-before-rollback-*`。成功切换前停止旧 Shell 后生成的最终快照保存在 `final/`；`final/prepared`
已存在，不要重跑首次切换入口 `activate-test.sh` 或 `migrate-files.py prepare`。

当前已运行并固化、包含 Home Manager 挂载顺序修正的系统：

```text
/nix/store/nm4gfibf5dis6zkxhi798fc7jallrwfd-nixos-system-apollo-26.11.20261014.55bfb4d
```

`apply-correction.sh` 已由用户在本地终端执行，`/run/current-system` 已指向上述路径。
`home-manager-vitus.service` 的 `RequiresMountsFor` 包含 `/home/vitus/.local/state/noctalia` 和
`/home/vitus/.local/share/noctalia`，激活成功。旧的 `mbg9ab…`
仅为首次 test 代，不再作为后续部署目标。

真实密码验收已通过，详见
[PAM 记录](./lockscreen-pam.md#本轮验收状态与阻断条件)。用户随后在本地终端对同一修正版完成以下
`switch`，无需重新构建：

```bash
nixos-rebuild switch --no-reexec --sudo --store-path /nix/store/nm4gfibf5dis6zkxhi798fc7jallrwfd-nixos-system-apollo-26.11.20261014.55bfb4d
```

11:18 核对 `/nix/var/nix/profiles/system` 与 `/run/current-system` 均指向上述修正版。Home Manager
`Result=success`、`ExecMainStatus=0`，两个运行目录的挂载依赖已加载；Noctalia 与 hypridle 均 active、`NRestarts=0`，旧
`noctalia-shell.service` 为 not-found/inactive，IPC 返回
`barVisible=true`、`locked=false`。本机部署已完成，尚未重新登录或重启。

本机 `nixos-rebuild-ng` 会在使用 `--store-path` 前尝试构建并重执行自身；首次尝试因此在缺少
`nixos-config` 时失败。使用 `--no-reexec` 后已成功完成本轮 `test`
激活，后续切换和回滚同样保留该参数。

## 已执行验证与尚未实测

已完成：

- 原有 22 个 input 依赖闭包逐项比较未变；主 nixpkgs 保持
  `55bfb4d7437bd4e09ab7cba58a43bd68eb310044`。
- 两个源码补丁零 fuzz 应用；最终原生包构建并报告
  `noctalia v5.5.0 (c257324)`，apollo 完整系统构建成功。
- `just test` 返回 `true`；apollo/athena/generic 新服务、旧服务移除、ffmpeg-full 及 apollo 持久化
  `0700` 求值检查。
- 完整迁移 TOML、包含 Nix 生成 `plugins.toml`
  的最终配置目录校验无 ERROR、未知键或迁移 WARN。单独基础文件不带插件源会报插件未识别，须校验完整目录。TOTP 不支持的冗余
  `peek=false` 已移除，插件默认始终展开。
- 本地插件与固定社区番茄钟 lint 均
  `0 errors, 0 warnings`；两个 Luau 文件编译通过。私有 Luau 冒烟覆盖 UTF-8 截断、六位码保留、失败清码、防重叠、detached 动作与负载样本边界。
- TOTP 脚本在隔离 HOME 使用公开测试密钥与 oathtool 比对，覆盖缺失/空/无效配置、复制、切换、选择、取消。
- staged Niri 与切换后的活动 Niri 配置通过 `niri validate`；目录迁移保护与实际生成的 Home
  Manager 冲突检查通过。

实际桌面检查：

- 新服务为原生 5.5.0，IPC 正常；旧 `noctalia-shell.service`
  已不存在。新进程持有通知 D-Bus 与 StatusNotifierWatcher，普通通知实际显示。
- 启动器打开并启动 kitty；`Terminal=true` 测试入口实际显示
  `terminal-launch-ok`。启动器启动的 kitty 任务在 Shell 重启后继续运行。
- 双窗口 urgent 聚合：A/B 同时请求注意时显示红点；聚焦 A 后 B 仍 urgent，当前胶囊保留红点；聚焦 B 后清除，切走不重现。
- 工作区 hover、点击、滚轮、空命名工作区进入/离开和完整数字 `10` 均检查；滚轮实测从 `2browser` 切到
  `3docs`。
- 网络、蓝牙与系统监控页面实际打开，监控图表有实时数据；托盘抽屉显示六个已注册图标。未改变网络连接或蓝牙配对。
- 加密文本与图片剪贴板历史在 Shell 重启后恢复；从面板复制已知测试图片，297 字节与重启前完全一致。
- TOTP 真实左键复制得到六位码、右键切换、中键打开选择器；选择器超过 5 秒仍存活，取消保留索引，测试后恢复原选择。验证码不作为验收输出。
- 番茄钟 start/pause/skip/reset-all 与一分钟实际到时检查完成；到时停在
  `Short Break 05:00`，从默认输出 monitor 录到闹铃。第一次 `pw-record`
  录音退出码为 1，未作通过依据；改用已校准的默认 sink
  monitor 后录音成功，到时约 60.8 秒出现声音。测试后恢复 25/5/15/4，回到第一轮 Work 25:00。
- 用户在修正版 `test` 系统完成真实密码验收；11:12:31 的错误认证被 `noctalia-lock`
  拒绝，11:12:34.923 随后请求解锁。检查时新 Shell 与 hypridle 均 active、`NRestarts=0`，IPC 报告
  `locked=false`。account 阶段警告及版本边界见 PAM 专题。

私有截图、录音和检查产物位于备份的
`acceptance/`；含桌面、剪贴板或验证码区域的原始截图仅作本机证据，不作为共享附件。

固定 community 仓库扫描会输出五条其他禁用插件的 manifest setting
shadow 日志；它们不是迁移 TOML 的未知键或迁移警告，不修改固定社区仓库来消除日志。

物理全局快捷键未验收；合成按键未触发 Niri 全局绑定，不能据此记为通过。当前只有 DP-1（logical
2061×1159，scale≈1.24167）；多屏与 eDP-1 布局、外接亮度、20 分钟 idle、suspend/resume、重新登录和重启均未实测。

## 回滚

恢复必须覆盖系统包、HM
generation、仓库文件、活动快捷键和目录所有权；仅回滚 generation 不会恢复 out-of-store 配置。

本轮私有脚本可执行恢复的文件步骤；下面命令须在已经发生本轮切换后执行：

```bash
systemctl --user stop noctalia hypridle
python3 /home/vitus/tmp/noctalia-v5-20261113-021311/migrate-files.py restore
nixos-rebuild switch --no-reexec --sudo --store-path /nix/store/vp6qkclhhd45q2gcm4d9ryc370j02gz9-nixos-system-apollo-26.11.20261014.55bfb4d
/nix/store/bhma59flkkm77x36g919dmjhmls53m6b-home-manager-generation/activate
systemctl --user daemon-reload
systemctl --user start noctalia-shell
systemctl --user restart hypridle
noctalia-shell ipc call state all
```

文件恢复步骤先把 v5
state/data 另存到同一私有备份内，再恢复本轮涉及的原始仓库文件及任务前用户改动、最终 v4
JSON/QML、Niri 绑定与旧配置目录 symlink。新运行数据不会删除。确认 Alt+Space、工作区与 TOTP 恢复后再处理本轮 Git 暂存项；不使用
`git reset --hard`，不覆盖用户其他文件。

## 固定上游依据

- [5.5.0 发布](https://github.com/noctalia-dev/noctalia/releases/tag/v5.5.0)、[官方包](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/nix/package.nix)
- [配置层与数据位置](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/configuration/index.mdx)、[systemd 服务](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/compositor-settings/systemd-service.mdx)
- [Niri 集成](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/compositor-settings/niri.mdx)、[插件 API](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/plugins/development/runtime-api.mdx)
- [固定番茄钟 manifest](https://github.com/noctalia-dev/community-plugins/blob/33d7ba696a6644016ae3c0706c0b5fcf066e42e8/pomodoro/plugin.toml)
