# Croc 上游包维护

## 当前行为

`modules/base/packages.nix` 安装主 nixpkgs 的 `pkgs.croc`，当前为 `11.5.5`。 `overlays/croc/`
已删除，不再覆盖源码或删除 vendor 目录。

锁定来源为 nixpkgs
`d5cc6833999746cffdfe0598f7bc801a57b887a9`；源码固定和 Go 依赖由上游配方维护。本次只清理声明，未部署系统。

## 已退役的覆盖

历史上曾针对 `10.4.5` 的源码 hash 变化和 `11.5.4` 的 vendor 问题维护本地 overlay。当前包升级到
`11.5.5`
后直接使用上游配方，不再保留旧 hash 或构建补丁。历史失败记录不适用于当前包，也不能作为重新添加旧覆盖的依据。

## 回滚

需要回滚时恢复升级前的 nixpkgs lock 及当时配套 overlay，不能把 `10.4.5`
的 hash 覆盖应用到新版。曾针对 `11.5.4` 删除过期 vendor 的临时处理也不再保留；上游 `11.5.5`
已更换源码。

## 验证

```bash
nix build .#nixosConfigurations.apollo.pkgs.croc --no-link --print-build-logs
nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace --print-build-logs
```
