# GnuPG

GnuPG 是 OpenPGP 标准的实现，用于管理 PGP key、签名、验证、加密和解密。

在这份文档中:

- GPG 指 `gpg` / GnuPG 工具
- PGP 指 OpenPGP 标准中的概念，例如 PGP key、key server

当前使用方式:

- age: 用于 agenix secrets、SSH key 和简单文件加密
- GnuPG: 用于 password-store、邮件加密和签名

参考:

- <https://www.gnupg.org/>
- <https://wiki.archlinux.org/title/GnuPG>
- <https://www.gnupg.org/documentation/guides.html>

## 基础密码学资料

- <https://github.com/nakov/Practical-Cryptography-for-Developers-Book>
- <https://thiscute.world/tags/cryptography/>

## GPG 如何保护私钥

GnuPG 会分别生成 secret
key，并用从 passphrase 派生出的对称密钥加密保护。OpenPGP 使用 String-to-Key，也就是 S2K，从 passphrase 派生对称密钥。

更强的 S2K 选项示例:

```bash
gpg --s2k-mode 3 --s2k-count 65011712 --s2k-digest-algo SHA512 --s2k-cipher-algo AES256 ...
```

当前 Home Manager 中通过 `programs.gpg.settings` 统一设置相关参数。

## 生成主 key

交互式生成:

```bash
gpg --full-gen-key
```

建议选择:

- ECC
- Curve 25519
- 设置过期时间
- 使用强 passphrase

GPG 2.4.x 默认已经倾向 ECC + Curve 25519，通常可以直接使用默认值。

## GPG 目录结构

默认目录是 `~/.gnupg`。

常见文件:

```text
~/.gnupg/
├── S.gpg-agent
├── S.gpg-agent.browser
├── S.gpg-agent.extra
├── S.gpg-agent.ssh
├── common.conf
├── openpgp-revocs.d/      # 吊销证书
├── private-keys-v1.d/     # 私钥
├── public-keys.d/         # 公钥
└── trustdb.gpg            # trust database
```

Home Manager 管理大部分配置文件，但不会管理:

- `~/.gnupg/openpgp-revocs.d/`
- `~/.gnupg/private-keys-v1.d/`

这是预期行为，私钥和吊销证书不能随普通配置文件管理。

## Subkey 最佳实践

OpenPGP key 有不同用途标记:

- `C`: certify，用于创建、修改、吊销其他 key
- `S`: sign，用于签名
- `E`: encrypt，用于加密
- `A`: authenticate，可作为 SSH key 等认证用途

推荐做法:

1. 生成主 key，使用现代算法，例如 ECC + Curve 25519
2. 分别生成 `E`、`S`、`A` subkey
3. 主 key 只用于管理 key，本机日常使用只保留 subkey
4. 主 key 和吊销证书离线备份，例如两个加密 U 盘，分开放置
5. 备份完成后，从日常机器删除主 key 和吊销证书

添加 subkey:

```bash
gpg --expert --edit-key <email-or-key-id>
```

进入交互界面后:

```text
gpg> addkey
gpg> save
```

查看 key 和 subkey:

```bash
gpg --list-secret-keys --with-subkey-fingerprint
gpg --list-public-keys --with-subkey-fingerprint
```

## 备份和恢复

导出公钥:

```bash
gpg --armor --export <email-or-key-id> > public-keys.asc
nix run nixpkgs#pgpdump public-keys.asc
```

只导出主私钥:

```bash
gpg --armor --export-secret-keys <primary-key-id>! > primary-key.priv
```

注意 key ID 末尾的 `!`，它表示只导出指定 key，不导出 subkeys。

导出 subkeys:

```bash
gpg --armor --export-secret-subkeys <email-or-key-id> > subkeys.priv
```

导出的私钥仍然受 GPG
passphrase 保护，但 OpenPGP 导出格式可能没有使用你期望的最强参数。建议再用 age 加一层:

```bash
age --passphrase -o primary-key.priv.age primary-key.priv
rm primary-key.priv

age --passphrase -o subkeys.priv.age subkeys.priv
rm subkeys.priv
```

恢复时先解密，再导入:

```bash
age --decrypt -o subkeys.priv subkeys.priv.age
gpg --import subkeys.priv
rm subkeys.priv
```

公钥建议通过 Home Manager 的 `programs.gpg.publicKeys` 导入，不要手工散落执行 `gpg --import`。

## 删除日常机器上的主 key

备份确认后，删除日常机器上的主 secret key:

```bash
gpg --delete-secret-keys <email-or-key-id>
```

删除本地吊销证书:

```bash
rm ~/.gnupg/openpgp-revocs.d/<fingerprint>.rev
```

然后只导入 subkeys。再次查看时，如果主 key 显示为 `sec#`，表示本机没有主私钥，这是预期状态。

## 签名和验证

明文签名:

```bash
gpg --clearsign <file>
```

生成 detached signature:

```bash
gpg --armor --detach-sign <file>
```

验证:

```bash
gpg --verify <file>
gpg --verify <signature-file> <file>
```

## 加密和解密

使用对方公钥加密，并用自己的签名 key 签名:

```bash
gpg --armor --sign --encrypt --recipient <recipient> <file>
gpg -aser <recipient> <file>
```

解密:

```bash
gpg --decrypt <file>
gpg -d <file>
```

快速对称加密时更推荐 age:

```bash
age --passphrase -o file.age file
age --decrypt -o file file.age
```

GPG 也可以做对称加密:

```bash
gpg --armor --symmetric --cipher-algo AES256 <file>
gpg --decrypt <file>
```

## 公钥交换和吊销

OpenPGP 最大的问题之一是公钥分发和吊销不够可靠。

不建议依赖公共 key server:

- key server 不验证上传者身份
- 上传内容通常无法删除
- 容易泄露真实姓名、邮箱等隐私
- 任何人都可以上传声称属于某人的 key

吊销证书也需要手工分发。别人只有导入你的吊销证书后，才会知道某个 key 已经被吊销。

更现实的做法:

- 在个人主页、GitHub profile 或可信渠道发布公钥
- 出现泄漏时发布吊销证书
- 对重要通信通过额外渠道确认 fingerprint

导入吊销证书:

```bash
gpg --import <revocation-certificate>
```

查看吊销状态:

```bash
gpg --list-keys --keyid-format=long
```

## SSH agent

如果使用 GPG authentication subkey 作为 SSH key，需要启用 `gpg-agent` 的 SSH support，并导出:

```bash
export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
```

本仓库里主要通过 Home Manager 管理相关配置。

## 参考

- [2021 年，用更现代的方法使用 PGP（上）](https://ulyc.github.io/2021/01/13/2021%E5%B9%B4-%E7%94%A8%E6%9B%B4%E7%8E%B0%E4%BB%A3%E7%9A%84%E6%96%B9%E6%B3%95%E4%BD%BF%E7%94%A8PGP-%E4%B8%8A/)
- [Predictable, Passphrase-Derived PGP Keys](https://nullprogram.com/blog/2019/07/10/)
- [OpenPGP - The almost perfect key pair](https://blog.eleven-labs.com/en/openpgp-almost-perfect-key-pair-part-1/)
