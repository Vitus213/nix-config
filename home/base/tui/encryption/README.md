# 加密工具

这个目录说明终端环境中的加密工具选择。

## 当前工具

- GnuPG: 密钥、签名、password-store
- password-store: 密码管理
- LUKS2: Linux 磁盘加密
- rclone crypt: 跨平台数据加密和同步
- age: 文件加密和 agenix secrets
- SOPS: 可选方案，适合结合云 KMS

## 非对称加密

age、SOPS 和 GnuPG 都能做非对称加密，用于把文件加密给指定身份。现代文件加密优先考虑 age；如果需要云 KMS，考虑 SOPS。

## 对称加密

age 和 GnuPG 都支持基于 passphrase 的对称加密。age format v1 使用 scrypt 保护 file
key，适合简单文件加密场景。

参考: <https://age-encryption.org/v1>
