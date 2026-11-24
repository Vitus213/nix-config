# Secrets 管理

这个目录定义当前仓库如何通过 agenix 使用私有 secrets。真正的密文文件放在 private
secrets 仓库里，并作为 flake input 传入本仓库。

应用、网站和密码仓库相关内容见
[home/base/tui/password-store](../home/base/tui/password-store/README.md)。

## 当前约定

- 普通 NixOS 主机和 Darwin 主机使用 `/etc/ssh/ssh_host_ed25519_key` 作为 agenix identity
- 启用 preservation 的 NixOS 主机直接使用 `/persistent/home/vitus/.ssh/id_ed25519`；它与挂载后的
  `~/.ssh/id_ed25519` 是同一把钥匙
- NixOS 配置入口是 `secrets/nixos.nix`
- Darwin 配置入口是 `secrets/darwin.nix`
- 独立 home-manager 配置入口是 `secrets/home.nix`
- 本机 private secrets 仓库路径是 `/home/vitus/my-secrets`

不要在 Nix 配置里写 `~/.ssh/id_ed25519`。`~` 是 shell 展开规则，Nix 模块里不会自动展开。

## FlClash 订阅

`secrets/flclash.nix` 为 Artemis、Athena 和 Apollo 声明
`/run/agenix/flclash-subscriptions`。密文包含 J1900 的 `新增订阅` 和 `SELOM`
两条地址。三台的现役 agenix identity 可解密，运行时文件归 `vitus`，权限为 `0400`。

## NixOS 运行时文件与旧持久化迁移

`secrets/nixos.nix` 将用户可读数据统一声明为 `owner = vitus`、`mode = "0400"`，不授予执行权限。六个
`/etc/agenix/*` 兼容入口仅指定 `source`，使用 NixOS 默认的 `mode = "symlink"`，不再复制明文到
`/etc`。消费者路径保持不变；`omp-keys` 继续直接使用 `/run/agenix/omp-keys`。

链路为 `/etc/agenix/<name>` → `/etc/static/agenix/<name>` → `/run/agenix/<name>` →
`/run/agenix.d/<generation>/<name>`。Nix store 中只记录链接目标，不包含解密后的内容。agenix 在
`/run/agenix.d` 的 ramfs 创建文件，父目录和 generation 目录权限为
`0751`，其他用户可遍历但不能列目录；文件归属 `vitus`，由文件的 `0400` 限制读取。不要用 `/etc`
链接本身的权限判断目标可读性。

旧配置将 `/etc/agenix` bind mount 到 `/persistent/etc/agenix`，该 preservation 声明已经移除。仅在
`modules.secrets.preservation.enable` 开启时，`retirePersistedAgenix` activation 会在 `agenix`
完成后运行，`etc` activation 显式依赖它。若 `/etc/agenix`
仍是挂载点，先用 inode/device 同一性确认它确实来自 `/persistent/etc/agenix`，再普通
`umount`。未知来源或卸载失败会终止激活；没有 force/lazy 卸载，也不会复制、覆盖或删除
`/persistent/etc/agenix` 中的历史明文。当次 `/etc` 激活因此能创建运行时链接，不会被旧 bind
mount 遮住。

历史副本仍可能存在于
`/persistent/etc/agenix`，本次清理不会自动擦除。它们不再作为当前 secret 的来源，日后如需归档或清理，应单独确认；本仓库没有增加删除运行数据的 activation。新生成文件的
`0400` 不会追溯收紧历史副本的权限；旧文件若曾为 `0644`，本次仍保留原状。

仅检查元数据的部署后确认方式（不读取 secret 内容）：

```bash
mountpoint /etc/agenix
readlink -f /etc/agenix/nix-access-tokens
namei -l /etc/agenix/nix-access-tokens
stat -Lc '%U %G %a %n' /etc/agenix/nix-access-tokens
sudo -u vitus test -r /etc/agenix/nix-access-tokens
```

预期 `mountpoint` 返回非挂载点，最终路径位于 `/run/agenix.d`，目标 owner 为 `vitus`、mode 为
`400`，用户可读。2026-11-15 Apollo 已 switch 并核对：挂载已移除，入口解析到
`/run/agenix.d/3`，六个目标均为 `vitus:users 0400` 且可读；历史持久化副本保留。回滚迁移应一起恢复
`/etc`
的复制声明和 preservation 映射，再按正常部署流程切换；不要只恢复旧映射，否则运行时链接会再次落到持久化目录。历史数据保留，回滚不需要删除它。

依据：[锁定 agenix 模块](https://github.com/ryantm/agenix/blob/4835b1dc898959d8547a871ef484930675cb47f1/modules/age.nix)、
[锁定 NixOS etc 模块](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/nixos/modules/system/etc/etc.nix)。

Darwin 的用户可读 secret 同样使用 `0400`，消费者直接读取 `/run/agenix`；旧 `/etc`
alias 过渡及 postActivation chown 已移除。Darwin 不执行上述 NixOS preservation mount 迁移。

### 启动解密与用户目录挂载

锁定的 NixOS `d5cc683` 在 initrd 中通过 chroot 执行系统 activation；preservation 的用户 `.ssh`
默认在切换根目录后才 bind mount。agenix 因此直接读取
`/persistent/home/vitus/.ssh/id_ed25519`，避免启动时读到尚未被挂载覆盖的旧 identity。若
`/persistent` 使用独立分区或 subvolume，必须将对应 `fileSystems` 声明设为
`neededForBoot = true`，保证 activation 前可访问。Apollo 当前 `/persistent` 位于 ext4 根分区中。

2026-11-16 排查确认：启动约 5.1 秒时七个 secret 均因 `no identity matched any of the recipients`
解密失败；用户 `.ssh` 到约 6.9 秒才挂载。当前正确 identity 能解密全部原密文，TOTP 密钥并未丢失。最近
`/etc/agenix` 从持久化明文改为运行时链接后，这次解密失败直接表现为 TOTP 不可用、Nushell `source`
文件缺失。不要通过删除 `source` 或恢复持久化明文来隐藏故障。

验证已覆盖最终 Apollo/Athena identity 求值、全部密文解密、真实 TOTP 展示脚本生成六位码，以及 Nushell
0.116.1 加载完整配置与解密后的 source；只输出验证结果，不输出密钥和验证码。 `just test`
与 Nix 格式检查通过，修复后的 activation 脚本已构建且 Bash 语法检查通过。本会话无免密 root，尚未恢复系统
`/run/agenix`，未切换系统或重启；开机行为仍需部署后重启验收。当前启动可在用户终端执行已构建的最小恢复入口：

```bash
sudo /nix/store/f2slczrpdkyd418jyi7frmf7v7vyjzww-apollo-restore-agenix
```

该入口由修复后的 agenix
activation 片段生成，只解密七个 secret、切换运行时链接并设置权限；不切换系统 generation。普通用户隔离冒烟已覆盖真实七个密文、链接与
`0400`，未执行 root ramfs 挂载与 chown。长期修复需要正常部署本仓库；上述 Nix
store 路径仅用于本次 Apollo 恢复，不能替代声明式部署。

依据：[NixOS initrd activation](https://github.com/NixOS/nixpkgs/blob/d5cc6833999746cffdfe0598f7bc801a57b887a9/nixos/modules/system/boot/systemd/initrd.nix#L763-L795)、
[preservation 挂载阶段](https://github.com/nix-community/preservation/blob/717cdb87ac3df05ca6865e1b31ee902e2e2d7952/module.nix)。

## Private secrets 仓库

本机 private secrets 仓库位于:

```text
/home/vitus/my-secrets
```

远端是:

```text
https://github.com/Vitus213/my-secrets.git
```

当前 `flake.nix` 通过 `mysecrets` input 引用这个仓库，并在 `flake.lock` 中锁定具体提交。修改
`/home/vitus/my-secrets` 后，需要先在 private secrets 仓库提交并推送，再回到本仓库执行:

```bash
nix flake update mysecrets
```

排查 secrets 解密失败时，优先对比三处状态:

```bash
git -C /home/vitus/my-secrets status --short
git -C /home/vitus/my-secrets log --oneline --decorate -5
jq '.nodes.mysecrets.locked' flake.lock
```

不要在本仓库文档或提交信息中写入 secret 明文、token、私钥内容或解密后的文件内容。

`master_key`
是 my-secrets 的主恢复私钥，按用户约定由这个 private 仓库正常跟踪和同步，用于兜底解密与 rekey；不要擅自取消跟踪或加入
`.gitignore`。工作文件权限保持 `0600`，仓库目录保持
`0700`。不得把私钥正文写进 nix-config、公开文档、聊天或日志；恢复跟踪不重新生成或轮换现有钥匙。

当前 `agenix 0.15.0` 在非交互 stdin 下执行 `agenix -r` 时，会把 `EDITOR` 设为
`cp -- /dev/stdin`。如果 stdin 为空，它会把已解密明文覆盖为空文件后再加密。rekey 前必须确认命令在真正交互式 TTY 中执行，或者改用显式临时明文加
`age --recipient ...` 的受控流程。

2026-06-29 已从 private secrets 仓库的 `f1ed2a6` 恢复并重新加密这些被空明文覆盖的文件:

- `alias-for-work.nushell.age`
- `github_token.age`
- `nix-access-tokens.age`
- `totp-secrets.conf.age`

对应修复提交是 `my-secrets` 的 `73fde417974f308959b1c904f34349fe9c3e9b49`。`ssh-key-romantic.age`
创建后历史中一直解密为空，需要重新找到原始私钥内容后再生成。

## 添加或更新 secret

以下操作在 private secrets 仓库中执行。

临时进入带 agenix 的 shell:

```bash
nix shell github:ryantm/agenix#agenix
```

或者使用 ragenix:

```bash
nix shell github:yaxitech/ragenix#ragenix
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
"/persistent/home/${myvars.username}/.ssh/id_ed25519"
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
