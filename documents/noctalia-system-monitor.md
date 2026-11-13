# Noctalia 系统监控

仓库固定 Noctalia **5.5.0**，入口为
`home/linux/gui/base/noctalia/config/config.toml`。apollo 已部署挂载顺序修正版并完成
`switch`；实际显示六项顶栏监控，系统监控页面有实时图表，未逐项校准读数精度。真实解锁已验收，配置层、验证范围与备份见
[Noctalia v5 专题](./noctalia-v5.md)。

## 顶栏监控项

六项按 CPU、负载、RAM、网络接收、网络发送、磁盘顺序放入 `system-monitor` 胶囊组。

| 实例     | 类型 / 数据源                                               | 显示                                                         |
| -------- | ----------------------------------------------------------- | ------------------------------------------------------------ |
| `cpu`    | 原生 `sysmon`，`stat="cpu_usage"`                           | CPU 使用率，不显示各核心                                     |
| `load`   | 本地 `vitus/desktop:load`，`noctalia.systemStats().loadAvg` | 1 分钟负载，一位小数；tooltip 为 1 / 5 / 15 分钟值，两位小数 |
| `ram`    | 原生 `sysmon`，`stat="ram_pct"`                             | 内存占用百分比                                               |
| `net_rx` | 原生 `sysmon`，`stat="net_rx"`                              | 网络接收速率                                                 |
| `net_tx` | 原生 `sysmon`，`stat="net_tx"`                              | 网络发送速率                                                 |
| `disk`   | 原生 `sysmon`，`stat="disk_used"`，`path="/"`               | 根路径所在文件系统的已用容量                                 |

原生项均使用
`visualization="none"`、显示数值与图标、`label_show_units=true`、`label_min_width=0`、`peek=false`，字体为
`Maple Mono NF CN`。网络使用自动单位 `network_speed_unit="auto"`，关闭紧凑格式。磁盘的 `disk_used`
与百分比 stat `disk_used_pct` 不同，不能把顶栏容量读数当成百分比。

`plugins/desktop/load.luau` 每 2000 ms 读取 Shell 已有系统采样，不启动额外进程或采样器；要求存在
`sampledAtMs` 和三项数值，否则显示 `—`
与“系统负载暂无样本”。负载是运行队列相关的平均值，不是 CPU 百分比。

原生项左键使用默认系统页入口，本地 load 明确设置 `panel-toggle control-center system`，对应命令为
`noctalia msg panel-toggle control-center system`。六项右键共用外部监控程序回退链：优先 Resources，然后 Mission
Center，再依次尝试已配置的其他桌面系统监控器；完整 argv 以各项 `.actions.right` 为准。

## 采样与阈值

`[system.monitor] enabled=true`，`gpu_poll_seconds=0`，顶栏不启用 GPU 监控组件。

| 配置前缀                     | `_activity_threshold` | `_critical_threshold` |
| ---------------------------- | --------------------- | --------------------- |
| `cpu_usage`                  | 80                    | 95                    |
| `cpu_temp`、`gpu_temp`       | 80                    | 90                    |
| `ram_pct`、`swap_pct`        | 80                    | 90                    |
| `disk_used`、`disk_used_pct` | 80                    | 90                    |

表中数值为对应 stat 的配置阈值；温度与容量 stat 不应一概解释为百分比。本地 load 没有另设阈值，网络项沿用原生默认。空闲磁盘阈值也沿用原生默认，没有照搬旧配置的逆序数值。

## 磁盘路径与版本边界

迁移后的磁盘组件只设置 `path="/"`，用于观察根文件系统；`/persistent`
是持久化数据的位置，不是本组件选定的路径。修改数据目录的持久化策略不意味着应同步修改监控路径。

4.7.7 历史配置使用 JSON `SystemMonitor.diskPath` 与面板 `diskPath`，旧实现按 `df`
的挂载点匹配，普通目录可能得到零值。这是旧版实现约束；v5 使用 TOML 原生 `sysmon`
与新的系统采样，不继续维护旧 JSON 两处字段，也不把旧版 `df` 匹配规则当作 v5 的当前限制。

## 固定版本来源

- [v5.5.0 系统监控 schema](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/src/config/schema/config_schema_system.cpp)
- [v5.5.0 插件 entry API](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/plugins/development/entries.mdx)
- [v5.5.0 配置层与覆盖顺序](https://github.com/noctalia-dev/noctalia/blob/v5.5.0/docs/user/configuration/index.mdx)
