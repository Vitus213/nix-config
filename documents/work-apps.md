# 浏览器与工作协作应用

本文记录 Linux 桌面上的浏览器，以及 `apollo` 的 Slack、Notion、Linear。

## 浏览器

只装两个浏览器，配置在 `home/linux/gui/base/browsers.nix`，所有 Linux 桌面主机通用：

| 浏览器        | 来源                       | 用途                                                       |
| ------------- | -------------------------- | ---------------------------------------------------------- |
| Zen Browser   | flake input `zen-browser`  | 主浏览器，原生 Wayland，见 [Zen Browser](./zen-browser.md) |
| Google Chrome | 主 nixpkgs `google-chrome` | 第二浏览器；同时用来打开 Notion / Linear 网页 App          |

`modules.desktop.forceX11Compat` 开启时（apollo），Chrome 带 `--ozone-platform=x11`
启动，与 VSCode 一致，避免 4K 缩放下 Fcitx 候选框偏移。

## 工作协作应用（仅 apollo）

由 `modules.desktop.workApps.enable` 控制，配置在 `home/linux/gui/base/work-apps.nix`，在
`hosts/olympians-apollo/home.nix` 中开启。

| 应用   | 形式                       | 原因                                                |
| ------ | -------------------------- | --------------------------------------------------- |
| Slack  | nixpkgs 官方客户端 `slack` | 有官方 Linux 版                                     |
| Notion | Chrome `--app` 网页 App    | 官方只有 macOS / Windows 客户端                     |
| Linear | Chrome `--app` 网页 App    | 官方只有 macOS / Windows 客户端，Linux 不在路线图上 |

不使用 `notion-electron` 等第三方包装：它们由第三方维护，不比官方网页更可控。

网页 App 的启动命令形如：

```bash
google-chrome-stable --user-data-dir=~/.local/share/webapps/notion --class=notion --app=https://www.notion.so
```

- 独立 `--user-data-dir`：每个网页 App 是单独的 Chrome 进程，登录态互不影响，`--class` 才能生效。
- `--class`：设置窗口 app-id（`notion` / `linear`），供 niri 窗口规则匹配。

## 窗口分配

规则在 `home/linux/gui/niri/conf/windowrules.kdl`，工作区语义见
[Niri 工作区与窗口分配](./niri-workspaces.md)：

| 应用   | app-id                            | 工作区     |
| ------ | --------------------------------- | ---------- |
| Chrome | `google-chrome` / `Google-chrome` | `2browser` |
| Notion | `notion`                          | `3docs`    |
| Linear | `linear`                          | `3docs`    |
| Slack  | `slack` / `Slack`                 | `6chat`    |

## 持久化

apollo 的家目录在重启时清空，以下目录已加入 `hosts/_shared/preservation.nix`，保留登录态：

- `~/.config/google-chrome`：Chrome 主配置
- `~/.local/share/webapps`：Notion / Linear 网页 App 的独立配置
- `~/.config/Slack`

## 验证

```bash
nix eval .#nixosConfigurations.apollo.config.home-manager.users.vitus.xdg.desktopEntries.notion.exec
```

部署后打开应用，用 `niri msg windows`
确认 app-id 与工作区。若 app-id 与规则不符（例如 XWayland 下大小写不同），按实际值调整
`windowrules.kdl`。

## 待办

- Claude Desktop：官方 Linux Beta 只提供 `.deb` / apt 源，nixpkgs 尚无打包，需要基于官方 `.deb`
  自行打包后再加入；窗口规则 `title="^Claude"` → `4codex` 已存在。
