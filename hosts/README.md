# 主机配置

这个目录存放所有主机相关配置，包括 NixOS、nix-darwin 和独立 home-manager 主机。

## 当前主机

### 物理机

| 主机      | 平台  | 硬件                        | 用途                     | 状态   |
| --------- | ----- | --------------------------- | ------------------------ | ------ |
| `apollo`  | NixOS | Ryzen 5 5600 + RTX 3070 LHR | 主力桌面、游戏、日常使用 | 使用中 |
| `generic` | NixOS | 部署前替换硬件配置          | 通用桌面模板             | 模板   |
| `artemis` | macOS | MacBook Air M1              | 自用笔记本               | 使用中 |

### WSL 主机

| 主机     | 平台      | 硬件 | 用途                           | 状态   |
| -------- | --------- | ---- | ------------------------------ | ------ |
| `hestia` | NixOS-WSL | -    | Windows WSL 终端主机（无桌面） | 使用中 |

### 其他入口

- `hermes` 是 Ubuntu 上的独立 home-manager 配置

## 命名规则

| 目录前缀      | 含义                               | 例子                                    |
| ------------- | ---------------------------------- | --------------------------------------- |
| `olympians-*` | 以希腊神话命名的 Linux 主机        | `olympians-apollo`、`olympians-generic` |
| `darwin-*`    | macOS（nix-darwin）主机            | `darwin-artemis`                        |
| 无前缀        | 特殊形态主机                       | `hestia`（NixOS-WSL）                   |
| `_shared/`    | 多台主机共享的片段，不对应具体机器 | `preservation.nix`、`nvidia.nix`        |

flake output 名去掉前缀：`hosts/olympians-apollo` → `.#apollo`，`hosts/darwin-artemis` →
`.#artemis`。

注意 `olympians-hermes/` 只有 `home.nix`：`hermes`
是 Ubuntu 上的**独立 home-manager**，不是 NixOS，由 `outputs/x86_64-linux/src/olympians-hermes.nix`
生成 `homeConfigurations.hermes`。

## 添加新主机

最稳妥的方式是复制一个相近主机目录，再逐项调整。不要只改 hostname 后直接部署。

WSL 主机不需要 `hardware-configuration.nix`：改为导入 `nixos-wsl` 模块并设置 `wsl.enable` /
`wsl.defaultUser`，参考 `hosts/hestia/`。

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

`modules/nixos/base/remote-building.nix` 打开了 `nix.distributedBuilds`，但 `nix.buildMachines`
目前为空（原有构建机条目继承自上游仓库，已全部注释），所以**实际上所有构建都在本机进行**。

需要远程构建时，在该文件里添加构建机条目，并在 `vars/networking.nix` 的 `hostsAddr`
中补充对应主机地址；SSH 密钥使用 agenix 下发的 `/etc/agenix/ssh-key-romantic`，见
[Homelab SSH Key](../documents/homelab-ssh-key-romantic.md)。

## 相关文档

- [全新 NixOS + preservation 部署流程](../documents/fresh-nixos-preservation-deploy.md)
- [通用 NixOS 桌面 Host](../documents/generic-nixos-host.md)
- [hestia（NixOS-WSL 终端主机）](../documents/hestia-wsl.md)
- [主机共享模块 `_shared/`](../documents/host-shared-modules.md)
- [rEFInd 启动配置](../documents/refind-boot.md)
- [NixOS 内核策略](../documents/nixos-kernel.md)
