# Tern 同名项目辨析与安装调查

调查日期：2026-11-13。本次仅研究，未修改配置或安装软件。

## 更正：用户指定的是 tern.build

此前调查对象误选为 Stencil
Tern。下方 Stencil 的封闭测试限制、社区 Nix 配方及 OMP 原生集成结论，不适用于用户实际提供的
https://tern.build/download 。

- 用户指定的 Tern 是 coding agent IDE；Mac
  app 与 CLI/TUI 共用 daemon。桌面端仅 macOS，CLI 支持 macOS、Linux x86-64/ARM64 和 FreeBSD
  x86-64。[下载页](https://tern.build/download)
- 下载页当前版本为 0.7.10，公开提供二进制与 checksums.txt，无需 Stencil 测试资格。[公开发布](https://github.com/Shubham-1994/homebrew-tern/releases/tag/v0.7.10)
- 官网列出 16 种预置 agent，未列 OMP；支持在 tab 中运行其他 CLI
  agent，但这不证明 OMP 有专用协议集成。[官网](https://tern.build/)
- Nix 应基于此项目的公开发布资产打包，而非使用下述 Stencil 社区配方。尚未进行该产品的安装或运行验证。

## 以下为另一个产品：Stencil Tern

## 产品关系

- OMP 是 coding
  agent；Tern 是同属 Stencil 的原生终端工作区，不是 OMP 的 CLI 子命令。Tern 也能运行普通 shell 和其他程序。[Stencil](https://stencil.so/)、[Tern 产品页](https://stencil.so/tern)
- OMP 可以通过 Tern Surface
  Protocol（TSP）发送语义 UI 树，由 Tern 负责原生布局和绘制；不支持 TSP 的终端则使用 ANSI 渲染。TSP 可以经 SSH 和会话 daemon 传输。[协议文档](https://docs.stencil.so/tern/protocol/index.md)
- 本机 OMP 18.13.1 的 `src/cli/update-cli.ts` 中，`managedInstallName` 明确识别 Tern 的
  `manager.json`：Tern 管理的 OMP 由 Tern 更新，`omp update`
  不接管它。这不代表现有 bun 全局安装会自动被替换。[上游源文件](https://github.com/can1357/oh-my-pi/blob/main/packages/coding-agent/src/cli/update-cli.ts)

## 获取与平台

- 官网仍标注 CLOSED
  BETA，需要 Stencil 账号加入候补名单并取得访问资格。[产品页](https://stencil.so/tern)、[构建下载页](https://build.stencil.so/tern)
- 官方支持矩阵列出 macOS、Linux、Windows 桌面端、iOS 与 Web 客户端；不能因 WKWebView 集成就推断 Tern 只支持 macOS。[支持矩阵](https://docs.stencil.so/tern/concepts/support-matrix.md)
- 匿名构建 API 未提供当前可下载版本与资产；本次未取得可验证的安装包、校验值或完整主程序许可。[产品 API](https://build.stencil.so/api/products)、[构建 API](https://build.stencil.so/api/products/tern/builds)
- 公开 `tern-sdk`
  是协议 SDK 与插件示例，不是终端主程序。[SDK](https://github.com/stencil-hq/tern-sdk)

## Nix 安装可行性

本次未找到 Stencil Tern 的 nixpkgs 正式包。`pkgs.tern`
是 PostgreSQL 数据库迁移工具，不可用它代替本产品。[nixpkgs 包定义](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/te/tern/package.nix)

已有社区打包实践，尚未在本机验证：

- [plumj-am/nixos](https://github.com/plumj-am/nixos/blob/master/packages/tern/tern.nix)：x86_64-linux，使用用户预先下载的官方文件并适配运行库。
- [pelikanade/flake](https://github.com/pelikanade/flake/blob/main/modules/packages/tern/default.nix)：以
  `requireFile` 要求用户提供官方文件并适配 NixOS。

建议路径：先获得官方测试资格并下载相应架构的 Linux 包，再根据实际二进制依赖编写本地 Nix 包，通过 Home
Manager 安装。获取受限文件可采用 `requireFile`
模式；不能把认证 token 放入 Nix 表达式或 store。是否需要 autoPatchelf、图形库或其他包装，必须检查实际资产后决定。

Nix
store 不可写，与普通 Linux 分发的自更新机制存在冲突；打包时需核实并处理更新行为。当前不提供未经运行验证的安装表达式，也不假造版本、下载地址或 hash。

## 验证范围

已读取官方产品页、TSP 文档、本机 OMP 版本和更新管理实现，以及 nixpkgs 同名包定义；研究代理补充官方支持矩阵、下载访问限制与社区包调查。未安装 Tern，未测试 GUI、Nix 构建或现有 OMP 配置兼容性。
