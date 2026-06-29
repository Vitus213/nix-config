# Homelab SSH Key `ssh-key-romantic`

本文记录当前 homelab SSH 专用密钥的管理方式。它只描述当前仓库实际配置，不记录任何私钥内容。

## 当前设计

`ssh-key-romantic` 是连接内网 `192.168.*` 主机使用的专用 SSH 私钥。Home Manager 的 SSH 配置会对
`192.168.*` 使用:

```sshconfig
IdentityFile /etc/agenix/ssh-key-romantic
IdentitiesOnly yes
ForwardAgent yes
```

这把 key 和 `/home/vitus/.ssh/id_ed25519` 不是同一个角色:

- `/home/vitus/.ssh/id_ed25519`: preservation NixOS 的 agenix identity，用来解密 secrets。
- `/etc/agenix/ssh-key-romantic`: homelab SSH 登录私钥，用来登录内网机器。

当前 `ssh-key-romantic` 的 public key 是:

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpmGeM4GP8Kv8lMTac4YYvBFmTO5qPoaHZgFz+FOkoG ssh-key-romantic homelab 2026-06-29
```

指纹:

```text
SHA256:Hxrb0W0iIlN8gHKowcouWUF13946VX9/hSj/M6biqm8
```

## 文件位置

私有 secrets 仓库:

```text
/home/vitus/my-secrets/ssh-key-romantic.age
```

`my-secrets/secrets.nix` 中声明:

```nix
"ssh-key-romantic.age".publicKeys = systems;
```

NixOS secrets 配置:

```text
secrets/nixos.nix
```

系统激活后解密出口:

```text
/etc/agenix/ssh-key-romantic
```

目标权限:

```text
0600 vitus
```

## 更新流程

在能解密现有 secrets 的机器上执行。当前 `apollo` 使用 preservation，因此 agenix identity 是:

```text
/home/vitus/.ssh/id_ed25519
```

生成或更新 `ssh-key-romantic.age` 时，不要在非交互 stdin 下执行 `agenix -r`。当前 `agenix 0.15.0`
在非交互 stdin 下会把 `EDITOR` 设为 `cp -- /dev/stdin`，空 stdin 会把 secret 明文写成 0 字节。

安全做法是在临时目录生成 SSH 私钥后，直接使用 `age` 按 `secrets.nix` recipients 加密:

```bash
cd /home/vitus/my-secrets
nix-instantiate --json --eval --strict -E \
  '(let rules = import ./secrets.nix; in rules."ssh-key-romantic.age".publicKeys)' |
  jq -r '.[]'
```

然后提交并推送 `my-secrets`，回到 `nix-config` 更新 `mysecrets` flake input:

```bash
cd /home/vitus/nix-config
nix flake update mysecrets
```

最后切换系统配置后，确认:

```bash
stat -c '%U %G %a %n' /etc/agenix/ssh-key-romantic
ssh -G 192.168.100.1 | rg 'identityfile|identitiesonly|forwardagent'
```

## SSH Config 权限处理

OpenSSH 的 per-user config 是
`~/.ssh/config`。该文件权限必须严格，至少不能被其他用户写入。当前环境里 Home Manager 生成的
`~/.ssh/config` symlink 指向 Nix store，而 Nix store owner 显示为 `nobody:nogroup`，OpenSSH 会报:

```text
Bad owner or permissions on /home/vitus/.ssh/config
```

因此当前 Home Manager 配置在激活后把生成的 symlink 转成用户拥有的普通文件:

```text
/home/vitus/.ssh/config
```

目标权限:

```text
0600 vitus
```

## 路由器授权

`ssh-key-romantic` 只解决本机 SSH 私钥可用问题。要让它登录软路由，仍需要把 public
key 加到路由器的 root 授权列表。

这属于凭据和路由器访问控制变更，执行前必须单独确认。不要在未确认前修改路由器
`authorized_keys`、Dropbear 或 OpenSSH 配置。

## 验证

已执行:

```bash
nixfmt --check secrets/nixos.nix home/base/tui/ssh.nix
nix eval --json .#nixosConfigurations.$(hostname).config.age.secrets.ssh-key-romantic.file
nix eval --json .#nixosConfigurations.$(hostname).config.environment.etc."agenix/ssh-key-romantic".mode
```

`my-secrets` 已有密文 rekey 后，使用解密内容哈希确认以下 secret 明文未变化:

- `alias-for-work.nushell.age`
- `github_token.age`
- `nix-access-tokens.age`
- `totp-secrets.conf.age`

更正记录:

- 初次写入 `ssh-key-romantic.age` 时错误使用了非交互 stdin 路径，导致密文解密后是 0 字节。
- 2026-06-29 已重新生成全新的 Ed25519 SSH key，并直接通过 `age` 按 `secrets.nix` recipients 加密。
- 修正后解密出的私钥大小为 432 字节，能推导出上方 public key 和指纹。
- 新 public key 需要重新加入目标 homelab 主机的 `authorized_keys` 后才能用于 SSH 登录。
- 一次软路由 SSH 测试虽然成功，但 OpenSSH debug 显示认证方式是 `none`，不能作为 `ssh-key-romantic`
  已被路由器接受的证据。

## 回滚

如果要回滚本设计:

1. 在 `secrets/nixos.nix` 中移除 `ssh-key-romantic` 的 `age.secrets` 声明。
2. 移除 `environment.etc."agenix/ssh-key-romantic"` 映射。
3. 在 `home/base/tui/ssh.nix` 中删除或替换 `192.168.*` 的 `IdentityFile`。
4. 重新切换系统配置。

不要直接删除 `my-secrets/ssh-key-romantic.age`，除非确认所有主机不再引用它。

## 来源

- agenix README: https://github.com/ryantm/agenix
- ssh_config(5): https://man7.org/linux/man-pages/man5/ssh_config.5.html
