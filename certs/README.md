# 私有 PKI / CA

这个目录存放个人私有 CA 的公开证书和生成脚本，用于给自用服务签发证书。

## 文件

- `ecc-ca.crt`: ECC CA 证书
- `ecc-ca.srl`: CA 序列号
- `ecc-csr.conf`: OpenSSL CSR 配置
- `ecc-server.crt`: 由 ECC CA 签发的服务端证书
- `gen-certs.sh`: 证书生成脚本

## 安全约定

私钥文件 `*.key` 不进入 git，应该存放在 private secrets 仓库中。这里提交的是公开证书和配置文件。

生成证书:

```bash
./gen-certs.sh
```

对应的私钥管理见 [secrets](../secrets/)。
