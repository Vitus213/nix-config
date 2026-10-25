# Noctalia 系统监控磁盘路径

## 当前配置

- 配置入口：`home/linux/gui/base/noctalia/config/settings.json`（out-of-store
  symlink，Noctalia 运行时热加载）。
- 顶栏 `SystemMonitor` 组件和系统监控面板的 `diskPath` 均为 `"/"`，显示根分区的占用。

## 约束

Noctalia 4.7.7 用 `df --output=target,...` 按**挂载点**读取磁盘数据，`diskPath` 必须与 `df` 的
`Mounted on` 列完全一致；填普通目录时查不到对应行，面板显示 `0% (0.0 / 0.0 GB)`。

apollo 与 generic 的根分区都是普通 ext4，`/persistent`（preservation 的持久化目录）只是根分区上的目录，不是独立挂载点，因此不能作为
`diskPath`。若以后改为 tmpfs 根 + 独立 `/persistent` 分区，再把 `diskPath` 改回 `/persistent`。

## 验证

```bash
df -x efivarfs --output=target,pcent,used,size --block-size=1   # 确认挂载点
findmnt /persistent                                             # 无输出说明不是挂载点
noctalia-shell ipc call systemMonitor toggle                    # 打开面板查看 Disk 行
```

## 回滚

把两处 `diskPath` 改回原值，保存即生效。
