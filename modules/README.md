# 系统模块

这个目录存放 NixOS 和 nix-darwin 的系统级模块。模块按平台和功能拆分，主机入口只负责组合需要的模块。

## 目录结构

```text
modules/
├── base/      # NixOS 和 macOS 共享的基础配置
├── darwin/    # macOS / nix-darwin 专用模块
└── nixos/     # NixOS 专用模块
```

## `base/`

跨平台共享配置，主要包括:

- 字体
- Nix 基础设置
- overlays
- 安全基线
- 常用系统包
- 用户基础信息

这些模块应避免引用明显的平台专属选项。需要平台判断时优先使用 `pkgs.stdenv.isLinux` 或
`pkgs.stdenv.isDarwin`。

## `darwin/`

macOS 专用配置，主要包括:

- macOS 应用
- nix-darwin 系统设置
- Nix core 配置
- SSH
- 用户
- 安全设置
- 移除 darwin 上不兼容的包（overlay 在 `lib/macosSystem.nix` 中统一定义）

入口说明见 [modules/darwin/README.md](./darwin/README.md)。

## `nixos/`

NixOS 专用配置分两类:

- `base/`: 核心系统服务、网络、SSH、用户组、Nix、监控、zram 等
- `desktop/`: Wayland 桌面、字体、XDG、虚拟化、外设、桌面网络工具等

`modules/nixos/desktop.nix` 是桌面配置的组合入口。

## 使用原则

- 主机差异放在 `hosts/<host>/`
- 多台机器共享的系统能力放在 `modules/`
- 用户级配置放在 `home/`
- secrets 通过 `secrets/` 模块和 agenix 暴露，不要写进普通模块
- 新模块优先做成可开关选项，避免导入即生效

## 支持平台

- `x86_64-linux`: NixOS 桌面
- `aarch64-darwin`: Apple Silicon macOS
