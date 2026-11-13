# Delta（Zed 团队的 agent 协作环境）

本文记录 Delta 在 NixOS 桌面上的安装方式、二进制命名、更新和排障入口。

## 是什么

Delta 是 Zed Industries 在 2026-08 发布、2026-09 进入公测的独立应用，官方定位是"multiplayer
environment for coding with agents"。它不是 Zed 编辑器里的功能，也不替代 Git：

- 底层是 **DeltaDB**：在 Git 之上记录 commit 之间的每一次编辑（delta）和产生它的对话（人 +
  agent）。commit 仍是 checkpoint，照常 `git commit` / `git push`。
- 基本协作单位是
  **thread**：代码、prompt、agent 推理、diff 和评论放在一起；邀请队友后，对方在自己机器上拿到同一份 worktree（含未提交改动），可以接着让 agent 工作或 review。
- 有桌面 app、浏览器入口和 CLI；CLI 目前可把 **Claude Code** 会话同步进 thread，Pi 支持在开发中。

对单人使用，它接近"带 thread 记录的 agent 客户端"；多人协作时价值在于共享未提交工作和带上下文的 review。

## 与仓库里其他 "delta" 的区别

| 名称                         | 是什么                                                         | 入口                                             |
| ---------------------------- | -------------------------------------------------------------- | ------------------------------------------------ |
| Delta（Zed）                 | 本文主题，agent 协作应用                                       | `delta-app`、`delta-zed`、桌面项 `dev.zed.Delta` |
| `programs.delta` (git-delta) | diff/grep/blame 语法高亮分页器，`git diff \| delta` 用的就是它 | `delta`                                          |
| Zed 编辑器                   | 代码编辑器                                                     | `zed` / `zed-editor`                             |

**命名冲突**：上游 Delta 的 CLI 也叫 `delta`，与 nixpkgs 的 git-delta 冲突。`overlays/delta`
把 CLI 改名为 `delta-zed`，GUI 保持 `delta-app`；桌面项的 `Exec` 也同步改成 `delta-zed open %U`。

## 安装与配置入口

- `flake.nix`：`delta` input 指向
  `github:zed-industries/delta-nix`，`nixpkgs.follows = "nixpkgs"`，版本固定在 `flake.lock`（当前
  `0.23.0`）。
- `overlays/delta/default.nix`：包装上游包，提供 `pkgs.delta-zed`，内含：
  - `bin/delta-zed`：上游 CLI；
  - `bin/delta-app`：GUI；
  - `share/applications/dev.zed.Delta.desktop`、hicolor 图标（`Icon=dev.zed.Delta`）。
- `home/linux/gui/base/editors.nix`：把 `pkgs.delta-zed` 加入 `home.packages`。
- `home/linux/gui/niri/conf/windowrules.kdl`：`app-id="dev.zed.Delta"` 的窗口去 `1terminal`
  工作区并最大化。

上游只支持 `x86_64-linux` / `aarch64-linux`；macOS 不在本仓库 Nix 管理范围内。

## 字体与日志刷屏

Delta 使用 cosmic-text，按硬编码的 fallback 列表精确查找字族。仓库原先只有 Source Han（字族名是
`Source Han Sans` / `Source Han Serif`），没有
`Noto Sans CJK SC`，于是每个汉字都会逐字尝试 fallback，并产生 DEBUG 日志：

```
failed to find family 'Noto Sans CJK SC' for script Han
failed to find family 'FreeSans'
failed to find family 'DejaVu Sans Mono'
failed to find family 'FreeMono'
failed to find family 'Noto Sans Symbols2'
```

实测 30 分钟内写入约 409k 行、49 MB 日志，同时中文回退到
`Source Han Serif`，表现为字体发虚、衬线、输入卡顿。

修复在 `modules/base/fonts.nix`：启用 `noto-fonts-cjk-sans`（提供 `Noto Sans CJK SC`
字族名），并补充 `dejavu_fonts`、`freefont_ttf`。Source Han 系列保留，两者字形相同但字族名不同。

验证：

```bash
fc-match "Noto Sans CJK SC"   # NotoSansCJK-VF.otf.ttc
fc-match "DejaVu Sans Mono"   # DejaVuSansMono.ttf
```

修复后启动 Delta 15 秒，日志只增加 1 行，`font::fallback` 计数为 0。若仍看到
`Noto Sans Symbols2`（没有空格）的提示，那是 Delta 预设名的拼写问题，不影响中文渲染。

## 使用

从应用启动器打开 "Delta"，或：

```bash
delta-app            # GUI
delta-zed --help     # CLI
delta-zed open       # 启动/激活 GUI
delta-zed thread --help
```

首次使用需要在应用内登录并选择组织。桌面项注册了 `x-scheme-handler/delta`，分享链接会交给
`delta-zed open %U`。

## 更新

```bash
nix flake update delta
sudo nixos-rebuild switch --flake .#apollo
```

Delta 是闭源二进制（`license = unfree`），上游通过 `delta-nix` flake 的 `releases.json`
固定版本和hash；升级后先构建 `pkgs.delta-zed`，再运行 `delta-zed --version` 确认版本。

## 验证

```bash
nix build --impure --no-link --print-out-paths \
  --expr 'let f = builtins.getFlake (toString /home/vitus/nix-config); in f.nixosConfigurations.apollo.pkgs."delta-zed"'
/nix/store/...-delta-zed-0.23.0/bin/delta-zed --version   # delta 0.23.0
nix build --impure --no-link \
  --expr 'let f = builtins.getFlake (toString /home/vitus/nix-config); in f.nixosConfigurations.apollo.config.home-manager.users.vitus.home.path'
niri msg --json windows   # 启动后应看到 app_id = dev.zed.Delta
```

## 回滚

删除 `home/linux/gui/base/editors.nix` 中的 `pkgs.delta-zed`、`overlays/delta/default.nix`、
`flake.nix` 的 `delta` input 和 niri 对应窗口规则，再执行 `nix flake lock` 并 rebuild。

## 参考

- 产品页：<https://delta.dev>
- 发布说明：<https://zed.dev/blog/introducing-delta>、<https://zed.dev/blog/delta-public-beta>
- 官方 Nix 打包：<https://github.com/zed-industries/delta-nix>
- 早期访问协议：<https://delta.dev/early-access>
