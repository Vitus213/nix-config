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

### 外部系统

- SBC 主机在 [ryan4yin/nixos-config-sbc](https://github.com/ryan4yin/nixos-config-sbc) 中维护
- `hermes` 是 Ubuntu 上的独立 home-manager 配置

RISC-V 集群:

![](/_img/nixos-riscv-cluster.webp)

## 命名规则

- `olympians-*`: 希腊神话命名的 NixOS 桌面主机
- `darwin-*`: macOS 主机
- `apollo` / `athena` / `artemis`: 当前主要物理机
- `generic`: 不带个人 secrets 和 preservation 的通用 NixOS 桌面模板

## 添加新主机

最稳妥的方式是复制一个相近主机目录，再逐项调整。不要只改 hostname 后直接部署。

### 基本步骤

1. 在 `hosts/` 下创建新目录，例如 `hosts/olympians-<name>/`
2. 放入当前机器生成的 `hardware-configuration.nix`
3. 编写 `default.nix`，导入硬件配置、主机专用模块和可选的 `preservation.nix`
4. 如果需要 home-manager，添加 `home.nix`
5. 在 `outputs/<system>/src/<name>.nix` 中添加 flake output
6. 如需固定网络信息，在 `vars/networking.nix` 中补充主机地址

### 常用模板

- 桌面 NixOS: 参考 `olympians-apollo/`
- 无个人 secrets 的通用桌面 NixOS: 参考 `olympians-generic/`
- macOS: 参考 `darwin-artemis/`
- preservation: 参考 `olympians-apollo/preservation.nix`

## 分布式构建

我通常在 `apollo`
上发起构建，再由 Nix 分发到其他 NixOS 机器。对 riscv64、aarch64 或缓存缺失的包，这能减少主力机负担。

![](/_img/nix-distributed-building.webp)

![](/_img/nix-distributed-building-log.webp)

## 参考

- [Oshi no Ko 【推しの子】](https://en.wikipedia.org/wiki/Oshi_no_Ko)
- [The Rolling Girls 【ローリング☆ガールズ】](https://en.wikipedia.org/wiki/The_Rolling_Girls)
- [List of Twelve Kingdoms characters](https://en.wikipedia.org/wiki/List_of_Twelve_Kingdoms_characters)

![](/_img/idols-famaily.webp) ![](/_img/idols-ai.webp)

![](/_img/rolling_girls.webp)

![](/_img/12kingdoms-1.webp) ![](/_img/12kingdoms-Youko-Rakushun.webp)
