# 主机配置

这个目录存放所有主机相关配置，包括 NixOS、nix-darwin 和独立 home-manager 主机。

## 当前主机

### 物理机

| 主机      | 平台  | 硬件                        | 用途                     | 状态   |
| --------- | ----- | --------------------------- | ------------------------ | ------ |
| `apollo`  | NixOS | Ryzen 5 5600 + RTX 3070 LHR | 主力桌面、游戏、日常使用 | 使用中 |
| `athena`  | NixOS | 待补充                      | 第二台桌面               | 规划中 |
| `generic` | NixOS | 部署前替换硬件配置          | 通用桌面模板             | 模板   |
| `artemis` | macOS | MacBook Pro M4Pro 14" 48GB  | 工作机                   | 使用中 |

### 其他入口

- `hermes` 是 Ubuntu 上的独立 home-manager 配置

## 命名规则

- `olympians-*`: 希腊神话命名的 NixOS 桌面主机
- `darwin-*`: macOS 主机
- `apollo` / `artemis`: 当前主要物理机
- `athena`: 第二台 NixOS 桌面配置，仍处于规划/迁移状态
- `generic`: 不带个人 secrets 和 preservation 的通用 NixOS 桌面模板

## 添加新主机

最稳妥的方式是复制一个相近主机目录，再逐项调整。不要只改 hostname 后直接部署。

### 基本步骤

1. 在 `hosts/` 下创建新目录，例如 `hosts/olympians-<name>/`
2. 放入当前机器生成的 `hardware-configuration.nix`
3. 编写 `default.nix`，导入硬件配置、主机专用模块和可选的 `hosts/_shared/preservation.nix`
4. 如果需要 home-manager，添加 `home.nix`
5. 在 `outputs/<system>/src/<name>.nix` 中添加 flake output
6. 如需固定网络信息，在 `vars/networking.nix` 中补充主机地址

### 常用模板

- 桌面 NixOS: 参考 `olympians-apollo/`
- 无个人 secrets 的通用桌面 NixOS: 参考 `olympians-generic/`
- macOS: 参考 `darwin-artemis/`
- preservation: 参考 `hosts/_shared/preservation.nix`

## 分布式构建

我通常在 `apollo`
上发起构建，再由 Nix 分发到其他 NixOS 机器。对 riscv64、aarch64 或缓存缺失的包，这能减少主力机负担。

![](/_img/nix-distributed-building.webp)

![](/_img/nix-distributed-building-log.webp)

## 相关文档

- [全新 NixOS + preservation 部署流程](../documents/fresh-nixos-preservation-deploy.md)
- [通用 NixOS 桌面 Host](../documents/generic-nixos-host.md)
- [rEFInd 启动配置](../documents/refind-boot.md)
- [NixOS 内核策略](../documents/nixos-kernel.md)
