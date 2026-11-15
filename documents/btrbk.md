# btrbk 配置状态

`btrbk` 是 Btrfs subvolume 的快照和备份工具。它适合用于 `@persistent`、`@snapshots`
这类真实存在的 Btrfs subvolume 布局，不适合 ext4 持久化目录。

## 当前状态

当前桌面主机 `apollo` 的文件系统布局是：

- `/`：`ext4`
- `/boot`：`vfat`
- `/persistent`：位于 ext4 根分区中的持久化目录

`apollo` 没有 `/btr_pool`，也没有 `/snapshots` Btrfs 挂载点。因此共享模块不再启用 btrbk 实例，避免
`btrbk-btrbk.service` 查找 `/btr_pool/@persistent` 失败。

## 配置入口

旧 `modules/nixos/base/btrbk.nix`
只含注释模板，已删除。当前仓库不声明 btrbk 实例；需要恢复时，应在采用 Btrfs 的主机中新增真实配置，不再由所有桌面主机自动导入空模板。

## 什么时候需要启用

只有当某台主机重新采用 Btrfs subvolume 布局，并满足以下条件时，才应该恢复 btrbk：

- 存在真实的 Btrfs pool 挂载点，例如 `/btr_pool`
- 存在要快照的 subvolume，例如 `/btr_pool/@persistent`
- 如需本地保留快照，存在目标挂载点，例如 `/snapshots`
- `btrbk -c /etc/btrbk/btrbk.conf dryrun` 能找到 source subvolume

## 当前 Btrfs 引用

仓库里仍保留几类 Btrfs 文字引用，但它们不是当前 `apollo` 的启用配置：

- [LUKS + Btrfs 分区示例](./luks-btrfs-layout.md)：Btrfs 子卷布局参考。
- `documents/fresh-nixos-preservation-deploy.md`：说明可以选择 Btrfs subvolume 作为 `/persistent`。

## 验证

确认 `apollo` 没有启用 btrbk 实例：

```bash
nix eval .#nixosConfigurations.apollo.config.services.btrbk.instances --json --show-trace
```

确认 `apollo` 当前文件系统类型：

```bash
nix eval .#nixosConfigurations.apollo.config.fileSystems --json --show-trace
findmnt -R / -o TARGET,SOURCE,FSTYPE,OPTIONS
```

当前不需要运行 `btrbk run`。没有 Btrfs subvolume 时运行它只会失败。

本轮仅移除空配置文件及失效引用，未运行上述验证命令，也未删除任何快照、备份或 `/persistent`
数据。回滚仅需恢复主机的 btrbk 声明；应先满足真实 Btrfs 布局条件。
