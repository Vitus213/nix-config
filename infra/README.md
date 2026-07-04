# 基础设施代码

这个目录存放 Terraform 等基础设施配置，目前主要用于管理 MinIO 上的存储桶和 Terraform backend。

## 结构

```text
infra/
└── minio/
    ├── loki/           # Grafana Loki 日志桶
    └── tf-s3-backend/  # Terraform S3 backend 桶
```

## 使用方式

进入具体 workspace:

```bash
cd infra/minio/loki
```

使用脚本部署:

```bash
./run.sh
```

或者手动执行:

```bash
terraform init
terraform plan
terraform apply
```

## 相关配置

- Kubernetes YAML 不在当前仓库维护；这里只记录与 MinIO backend 和日志桶相关的 Terraform 配置
- secrets 由 [secrets](../secrets/) 和 agenix 管理

## 安全约定

- 凭据通过环境变量或 secrets 注入
- Terraform state 放在 MinIO backend
- 不要把 access key、secret key 或 token 写进仓库
