# macOS 入站 SSH

## 当前配置

artemis 使用 macOS 自带的 OpenSSH 服务端；本次恢复时版本为 macOS 26.5、OpenSSH 10.2p1。

- `modules/darwin/ssh.nix` 设置 `services.openssh.enable = true`，启用 Apple 的远程登录服务。
- `launchd` 监听 TCP 22，收到连接后按需启动服务端。因此，22 端口能连通不等于 SSH 已经正常工作。
- `modules/darwin/security.nix` 生成认证配置片段，保留 `PasswordAuthentication yes` 和
  `KbdInteractiveAuthentication no`。
- Apple 的 `sshd_config.d/100-macos.conf` 启用 `UsePAM yes`，用于系统账户的认证和会话处理。
- 公钥认证开启；`PermitRootLogin prohibit-password`，不允许 root 使用密码登录。

配置的管理边界：

- macOS 提供 `/etc/ssh/sshd_config`、Apple 默认片段和加密策略文件。
- nix-darwin 管理 `sshd_config.d/099-host-keys.conf`、`100-nix-darwin.conf`、
  `101-authorized-keys.conf`；仓库另外管理 `200-disable-password-auth.conf`。该文件虽然名称带有
  `disable-password-auth`，实际配置仍然允许密码认证。
- 主机密钥沿用 `/etc/ssh/ssh_host_*_key`，恢复默认配置时不重新生成密钥。

当前锁定的 nix-darwin `4cff07de74b50e64bdd68cd4e722ab5b6b35ee48`
只管理服务启用状态、配置片段和主机密钥，不生成 Apple 的主配置。缺失系统默认文件时，单纯重新执行 rebuild 不会补齐它们。

## 系统默认文件与恢复

服务端默认配置来自本机随系统提供的：

```text
/usr/share/openssh/default-configuration.tar.bz2
```

服务端及其依赖包括以下六个目标：

- `/etc/ssh/sshd_config`
- `/etc/ssh/sshd_config.d/100-macos.conf`
- `/etc/ssh/crypto.conf`，符号链接到 `crypto/apple.conf`
- `/etc/ssh/crypto/apple.conf`
- `/etc/ssh/crypto/fips.conf`，备用策略文件；当前未选择该策略
- `/etc/ssh/moduli`

普通文件使用系统包中的 `root:wheel`、`0644` 权限，`crypto/` 目录为
`0755`。仓库不接管整份 Apple 主配置，以免覆盖后续系统更新。

如果主配置缺失，`sshd -t` 会报告：

```text
/etc/ssh/sshd_config: No such file or directory
```

客户端可能在密码提示出现之前收到
`kex_exchange_identification: read: Connection reset by peer`。这种故障发生在服务初始化阶段，不是密码验证失败。文件为何丢失需要单独追查，不能仅凭症状归因。

确认文件确实缺失并取得修改授权后，可在本机 Nushell 中选择性恢复：

```nu
let members = [
  "private/etc/ssh/crypto/apple.conf"
  "private/etc/ssh/crypto/fips.conf"
  "private/etc/ssh/crypto.conf"
  "private/etc/ssh/moduli"
  "private/etc/ssh/sshd_config"
  "private/etc/ssh/sshd_config.d/100-macos.conf"
]
sudo /usr/bin/tar -xvpkjf /usr/share/openssh/default-configuration.tar.bz2 -C / ...$members
sudo /usr/sbin/sshd -t
```

归档中的 `private/etc/ssh/` 对应本机 `/etc/ssh/`。`-k` 保留已经存在的目标，`-p`
保留系统包权限；只提取列出的文件，不解包覆盖整个
`/etc/ssh`。这个步骤只处理缺失文件，不修正已有文件的内容。

恢复范围不包括客户端配置、Nix 管理的片段、授权公钥和主机密钥，也不修改端口、防火墙或代理。文件补齐并通过校验后，新连接即可使用；本次没有执行 rebuild 或重启服务。

## 验证

先运行 `sudo /usr/sbin/sshd -t`，再通过 `sudo /usr/sbin/sshd -T` 查看生效配置。关键结果为：

```text
port 22
usepam yes
permitrootlogin prohibit-password
pubkeyauthentication yes
passwordauthentication yes
kbdinteractiveauthentication no
```

配置校验不能代替真实登录。应分别从本机回环地址和另一台机器连接，并执行
`id -un; hostname`，确认密码认证、PAM、会话及用户 shell 均可使用。

2026-10-20 的实际验证：

- 本机连接 `vitus@127.0.0.1`，使用密码认证，命令返回 `vitus`、`artemis`，退出码为 0。
- 从 apollo（`192.168.100.205`）连接 artemis 当时的局域网地址
  `192.168.100.159`，使用密码认证，返回同样的用户与主机名，退出码为 0。该地址是本次验证现场地址，不是静态地址声明。
- 反向验证时，先将服务器指纹与本机 ED25519 公钥指纹核对，再确认连接；临时主机记录写入
  `/dev/null`，未修改 apollo 的 SSH 配置或授权公钥。
- 恢复前后，六个现有 Nix
  SSH 文件及 RSA、ECDSA、ED25519、DSA 四组主机公钥的 SHA-256 校验和一致。恢复成员不包含任何主机私钥。
- 密码仅用于交互式认证，没有写入配置文件或文档。

## 回滚与停用

本次只补齐原来不存在的六个目标，没有覆盖旧内容，因而没有被替换的文件需要还原。回退 Nix
generation 也不会撤销这些 macOS 系统文件。

正常停用入站 SSH 应在确认后把 `modules/darwin/ssh.nix` 的 `services.openssh.enable` 改为
`false`，再按正常部署流程激活。仅在系统设置中关闭远程登录，会被后续仍声明启用的 Nix 激活重新打开。

如必须精确撤销这次恢复，应在本地控制台先关闭远程登录，然后只移除上面列出的六个新增目标，保留 Nix 片段和所有主机密钥。这会重新造成无法登录，不作为正常停用方案。

## 参考资料

- [Apple：允许远程电脑访问 Mac](https://support.apple.com/guide/mac-help/allow-a-remote-computer-to-access-your-mac-mchlp1066/mac)
- [OpenSSH 10.2 服务端手册](https://github.com/openssh/openssh-portable/blob/V_10_2_P1/sshd.8)
- [当前锁定的 nix-darwin OpenSSH 模块](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/services/openssh.nix)
