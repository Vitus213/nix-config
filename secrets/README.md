# Secrets 管理

这个目录定义当前仓库如何通过 agenix 使用私有 secrets。真正的密文文件放在 private
secrets 仓库里，并作为 flake input 传入本仓库。

应用、网站和密码仓库相关内容见
[home/base/tui/password-store](../home/base/tui/password-store/README.md)。

## 当前约定

- 普通 NixOS 主机和 Darwin 主机使用 `/etc/ssh/ssh_host_ed25519_key` 作为 agenix identity
- 启用 preservation 的 NixOS 主机使用 `/home/vitus/.ssh/id_ed25519`
- NixOS 配置入口是 `secrets/nixos.nix`
- Darwin 配置入口是 `secrets/darwin.nix`
- 独立 home-manager 配置入口是 `secrets/home.nix`

不要在 Nix 配置里写 `~/.ssh/id_ed25519`。`~` 是 shell 展开规则，Nix 模块里不会自动展开。

## 添加或更新 secret

以下操作在 private secrets 仓库中执行。

临时进入带 agenix 的 shell:

```bash
nix shell github:ryantm/agenix#agenix
```

或者使用 ragenix:

```bash
nix shell github:ryan4yin/ragenix#ragenix
```

在 private secrets 仓库的 `secrets.nix` 中为新文件添加 recipients，例如:

```nix
let
  apollo = "ssh-ed25519 AAAA... vitus@apollo";
  artemis = "ssh-ed25519 AAAA... vitus@artemis";
  recovery_key = "ssh-ed25519 AAAA... recovery";

  systems = [
    apollo
    artemis
    recovery_key
  ];
in
{
  "./xxx.age".publicKeys = systems;
}
```

普通 NixOS / Darwin 主机获取 public key:

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub
```

启用 preservation 的 NixOS 主机获取 public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

交互式编辑 secret:

```bash
sudo agenix -e ./xxx.age -i /etc/ssh/ssh_host_ed25519_key

# preservation NixOS
agenix -e ./xxx.age -i ~/.ssh/id_ed25519
```

从已有明文生成 secret:

```bash
cat xxx | sudo agenix -e ./xxx.age -i /etc/ssh/ssh_host_ed25519_key

# preservation NixOS
cat xxx | agenix -e ./xxx.age -i ~/.ssh/id_ed25519
```

## 在本仓库使用 secret

NixOS 模块示例:

```nix
{ config, agenix, mysecrets, ... }:

{
  imports = [
    agenix.nixosModules.default
  ];

  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  age.secrets."xxx" = {
    file = "${mysecrets}/xxx.age";
    mode = "0400";
    owner = "root";
    group = "root";
  };
}
```

当前仓库的 preservation 分支会改用:

```nix
"/home/${myvars.username}/.ssh/id_ed25519"
```

## 新主机 rekey 流程

1. 在新主机上准备 agenix identity
   - 普通主机: `/etc/ssh/ssh_host_ed25519_key.pub`
   - preservation NixOS: `~/.ssh/id_ed25519.pub`
2. 把 public key 加入 private secrets 仓库的 `secrets.nix`
3. 在一台能解开旧 secrets 的机器上执行 rekey

普通主机:

```bash
sudo agenix -r -i /etc/ssh/ssh_host_ed25519_key
```

preservation NixOS:

```bash
agenix -r -i ~/.ssh/id_ed25519
```

4. 提交并推送 private secrets 仓库
5. 回到本仓库执行:

```bash
nix flake update mysecrets
```

## 常见问题

### `/run/agenix.d/*.tmp` 不存在

这通常不是 `chmod` 或 `mv` 的问题，而是更早的 age 解密失败。先检查:

```bash
nix eval .#nixosConfigurations.$(hostname).config.age.identityPaths --json
ls -la ~/.ssh/id_ed25519
```

确认当前 identity 对应的 public key 已经加入 private secrets recipients，并且已经 rekey、push、更新
`mysecrets` input。

### `/etc/agenix/*` 创建失败

如果前面同时出现 agenix 解密失败，先修 rekey。`/etc/agenix/*` 通常只是指向
`/run/agenix.d/<generation>/*` 的链接，源文件不存在时 `/etc` 阶段也会失败。

### 查看日志

NixOS:

```bash
journalctl | grep -5 agenix
```

Darwin:

```bash
tail -n 100 /Library/Logs/org.nixos.activate-agenix.stderr.log
tail -n 100 /Library/Logs/org.nixos.activate-agenix.stdout.log
```

## 相关项目

- [agenix](https://github.com/ryantm/agenix)
- [ragenix](https://github.com/yaxitech/ragenix)
