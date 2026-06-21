# 变量配置

这个目录存放跨 NixOS、nix-darwin 和 home-manager 复用的变量。

## 文件结构

```text
vars/
├── README.md
├── default.nix
└── networking.nix
```

## `default.nix`

主要内容:

- 默认用户名、全名、邮箱
- 新系统初始密码 hash
- SSH authorized keys
- 通用用户变量

这些值会被系统用户、home-manager、SSH 和远程构建配置引用。

## `networking.nix`

主要内容:

- 网关和代理网关
- IPv4 / IPv6 DNS
- 主机清单
- 每台机器的网络接口和地址
- SSH alias、known hosts、远程 builder 信息
- 物理机、虚拟机、Kubernetes 集群和 SBC 的网络拓扑

## 使用原则

- 新增主机时，优先在这里补充共享网络信息
- 不要在多个模块里重复写同一份地址或用户名
- 涉及密钥、密码和 token 的内容不要放在这里，应进入 private secrets 仓库并通过 agenix 使用
