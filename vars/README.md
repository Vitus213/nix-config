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

- `hostsAddr.apollo.ipv4`：生成 Apollo 的 SSH alias 和 known-host 地址
- `ssh.extraConfig`：Apollo、Artemis、Athena 与 j1900 的 SSH alias
- `ssh.knownHosts`：GitHub 和现有主机公钥

实际消费者是 `modules/base/users.nix` 的 `programs.ssh`。未消费的网关、DNS、IPv6、网卡和
`hostsInterface` 生成器已经删除；主机真实网络配置仍在
`hosts/*/default.nix`，本文件不接管地址或 DNS。重新添加网关等字段前应先有明确消费者；回滚只需恢复声明，不涉及网络或应用数据删除。
[此处的公钥属于公开 SSH host key，并非 secret](../secrets/README.md)。

## 使用原则

- 新增主机时，优先在这里补充共享网络信息
- 不要在多个模块里重复写同一份地址或用户名
- 涉及密钥、密码和 token 的内容不要放在这里，应进入 private secrets 仓库并通过 agenix 使用
