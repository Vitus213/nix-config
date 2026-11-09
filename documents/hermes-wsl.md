# hermes：Ubuntu WSL 的 Nix 用户环境

Ubuntu 24.04 WSL2 使用独立 Home Manager 配置 `homeConfigurations.hermes`。发行版为
`Ubuntu-24.04`，用户为 `vitus`；`hestia` 仍是原 NixOS WSL 主机。

## 部署与更新

先安装多用户 Nix，启用 `nix-command flakes`，再进入
`~/nix-config`。私有 my-secrets 仓库的访问凭据需要预先配置。

本机使用 `~/.ssh/hermes`
作为 agenix 身份，权限为 0600。公钥加入 my-secrets 的共享 recipients 后重新加密共享 secrets，保留已有接收者。私钥只保存在本机，不提交仓库。受限设备凭据不向新身份开放。

```sh
nix build .#homeConfigurations.hermes.activationPackage
./result/activate
```

首次激活前备份已有 dotfiles，避免覆盖本地配置。agenix 通过用户 systemd 服务解密，默认暴露在
`/run/user/1000/agenix`。OMP 和 WakaTime 从 Home Manager
agenix 提供的路径读取 secret；NixOS 保留原有路径。首次激活时 OMP 步骤可能早于 agenix 服务，服务完成后执行
`omp-sync-models` 生成模型配置。该命令会重建 `models.yml`，本机模型增量应先回填
`home/base/core/omp-models.yml.in`；详见 [OMP 模型管理](./omp-models.md)。

## 验证与回滚

确认 Nix daemon 和用户 systemd 可用，检查 `systemctl --user status agenix.service`
的退出结果；只检查 secrets 是否存在和权限正确，不打印内容。随后检查
`omp-sync-models`、Nushell、Helix 与 Zellij 是否可运行。

hermes 默认不启用 agent-usage-report 自动发布定时器。WakaTime 使用 agenix 的 secret 路径。若要回滚，可通过
`home-manager generations` 找到旧 generation 并执行其
`activate`；首次部署前已有 dotfiles 使用备份恢复。

KVM 属于 Windows、WSL 内核及用户组配置，不由 Home Manager 管理。使用普通用户验证 `/dev/kvm` 和
`KVM_CREATE_VM`；这不等同于完整 BoxLite 端到端测试。
