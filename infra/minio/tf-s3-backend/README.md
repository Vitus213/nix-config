# Terraform S3 Backend

这个 Terraform workspace 只用于创建存放其他 `tfstate` 文件的 MinIO bucket。

创建完成后，不需要把本 workspace 的 `terraform.tfstate` 提交或长期保存到仓库。
