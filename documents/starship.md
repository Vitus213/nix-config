# Starship 提示符

共享配置入口为 `home/base/core/starship.nix`，由 Home Manager 生成
`~/.config/starship.toml`，用于 Bash、Zsh 和 Nushell。

## 目录扫描超时

顶层
`scan_timeout = 100`，单位为毫秒。Starship 扫描当前目录以检测项目类型时，最多等待 100 毫秒；目录较大或存储较慢时，仍可能出现扫描超时警告。提高此值允许扫描更久，也可能增加提示符显示延迟。

Starship 1.27.0 的默认值为 30 毫秒，参见
[对应版本官方文档](https://github.com/starship/starship/blob/v1.27.0/docs/config/README.md#prompt)。此参数不改变执行外部命令的
`command_timeout`。

## 生效与验证

2026-11-16 已同步本机配置为 100 毫秒，并保留指向 Nix
store 的符号链接；下次提示符渲染即使用新值，无需重启终端。仓库配置随下一次正常 Home
Manager 部署生成相同设置；本次未切换整个系统。

验证：`starship print-config scan_timeout` 返回 `100`；共享 Nix 模块求值为
`100`。实际运行主目录与仓库目录的 `starship prompt` 均成功，未出现目录扫描超时警告。

## 调整与回滚

在共享 Nix 配置中修改 `scan_timeout`
并正常部署。删除该项即可恢复上游默认值；不要仅修改生成的 TOML，否则后续 Home
Manager 部署会覆盖本地修改。
