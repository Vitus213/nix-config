# Zen Browser

## 当前配置如何工作

Zen Browser 是 Firefox 的开源分支，默认左侧垂直标签栏，面向大量标签页的使用场景：

- Workspaces：多组互相隔离的标签工作区
- Split View：同一窗口内 2~4 格分屏
- Compact Mode：地址栏并入侧栏，节省纵向空间
- Zen Mods：主题与界面定制

本仓库通过 flake input `zen-browser`（`github:youwen5/zen-browser-flake`，上游 GitHub
Actions 每日自动跟随 Zen 上游发布更新）安装官方 Linux 二进制，用 nixpkgs 风格的 `wrapFirefox`
封装，版本固定于 `flake.lock`（当前 `1.21.14b`）。

Firefox 与 Google
Chrome 已从本仓库移除；Zen 是唯一安装的浏览器（Linux：`youwen5/zen-browser-flake`；macOS：Homebrew
cask `zen`）。未沙箱化。

## 安装入口

- flake input：`flake.nix` 的 `zen-browser`，`inputs.nixpkgs.follows = "nixpkgs"`
  与主 nixpkgs 共享系统库。
- 包安装：`home/linux/gui/base/browsers.nix`，引用
  `zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default`。
- 工作区规则：`home/linux/gui/niri/conf/windowrules.kdl`，`app-id="zen"` 打开到 `2browser`
  工作区并最大化。

该 flake 只提供 `x86_64-linux` / `aarch64-linux` 包；macOS（artemis）改经 Homebrew cask `zen`
安装（`modules/darwin/apps.nix`），AeroSpace 按 bundle id `app.zen-browser.zen` 将窗口分配到
`2Browser` 工作区。

## Wayland 行为

- Zen 是 Firefox 内核，走 Wayland 原生后端（Firefox 121+ 默认），无需额外环境变量；仓库已有的
  `MOZ_ENABLE_WAYLAND=1` 与其兼容。
- Wayland app-id 为 `zen`（来自 desktop 文件
  `StartupWMClass=zen`、`--name zen`）。niri 据此匹配窗口规则。
- 中文输入（fcitx5-rime）候选框行为正常：Firefox 内核没有 Wayland IME 候选框错位问题。

## 更新方式

```bash
nix flake lock --update-input zen-browser
nix eval .#evalTests
just local
```

## 验证方式

```bash
# apollo 主机含 Zen 的完整求值
nix eval .#nixosConfigurations.apollo.config.system.build.toplevel.drvPath

# 包构建与 desktop 文件（app-id）确认
nix build --no-link --print-out-paths 'github:youwen5/zen-browser-flake#zen-browser'
```

## 默认浏览器与自启动

Zen 目前是默认浏览器，由两处声明式配置共同决定：

- MIME 默认：`home/linux/gui/base/xdg/mime.nix` 的 `browser` 列表只有 `zen.desktop`；该模块强制写入
  `mimeapps.list`（`force = true`），运行时 `xdg-mime default` 的临时修改会在下次部署时被覆盖。
- `$BROWSER` 环境变量：`home/linux/base/shell.nix`，值为 `zen`。

登录自启动：`home/linux/gui/base/xdg/autostart.nix` 的 `xdg.autostart.entries` 使用 Zen flake
input 提供的 `zen.desktop` （`Exec=zen --name zen %U`，zen 二进制在用户 profile PATH 中）。

uBlock Origin 等扩展需首次启动后手动安装（Zen 支持 Firefox 全部附加组件）。

## 回滚

需要恢复 Firefox/Chrome 时（当前已移除）：

1. 恢复 MIME 默认浏览器：`home/linux/gui/base/xdg/mime.nix` 的 `browser` 列表加入
   `firefox.desktop`/`google-chrome.desktop`
2. 重新引入安装：Linux 在 `hardening/nixpaks/` 恢复 `firefox.nix` 并在
   `hardening/nixpaks/default.nix` 的 `nixpaks` 集合注册，`home/linux/gui/base/browsers.nix` 的
   `home.packages` 加入对应包；macOS 在 `modules/darwin/apps.nix` 的 casks 加入
   `firefox`/`google-chrome`
3. 恢复 `home/linux/gui/niri/conf/windowrules.kdl` 与 `home/darwin/aerospace/aerospace.toml`
   中对应窗口规则
4. 从 `home/linux/gui/base/browsers.nix` 的 `home.packages` 移除 zen-browser 条目、删除
   `home/linux/gui/niri/conf/windowrules.kdl` 中的 `app-id="zen"` 规则
5. 直接 `just local` 部署；`nix flake lock --update-input zen-browser` 不需要

## 参考

- 上游仓库：<https://github.com/zen-browser/desktop>
- Nix flake：<https://github.com/youwen5/zen-browser-flake>
- 发布页：<https://github.com/zen-browser/desktop/releases>
