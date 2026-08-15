# bb Agent IDE

本文记录 bb（`get-bb/bb`，agentic IDE）的安装来源、运行方式、更新与回滚。

## 当前配置

bb 通过用户级 npm 安装，命令为：

```bash
npm install -g bb-app@latest
```

当前安装版本：

| 组件 | 版本      | 来源                                 |
| ---- | --------- | ------------------------------------ |
| bb   | `0.37.0`  | npm 包 `bb-app`（`latest` dist-tag） |
| Node | `22.23.1` | 主 `nixpkgs` 的 `nodejs-slim`        |

bb 属于更新频繁的用户级 Agent 工具，沿用 OpenCode /
Pi 的既有约定：不通过 Nix 固定版本，跟随 npm 更新。npm 全局前缀由 `home/base/core/npm.nix` 固定为
`~/.npm`，`~/.npm/bin` 已经在 `home/base/core/shells/default.nix`（Bash）和
`home/base/core/shells/config.nu`（Nushell）的 PATH 中，安装后直接可用。

bb 对 Node 的 engines 要求是 `^22.19.0 || ^24.0.0 || ^26.0.0`；当前主 `nixpkgs` 的 `nodejs-slim`
22.23.1 满足要求。升级主 `nixpkgs` 时如果 Node 大版本变化，需要同步确认仍落在该范围内。

安装时 npm 会编译/下载原生模块 `node-pty`、`better-sqlite3` 与
`@parcel/watcher`，仓库已有的构建工具链可以直接完成，无需额外依赖。

## 运行方式

启动 launcher（前台进程，`Ctrl+C` 同时停止 server 与 host daemon）：

```bash
bb-app
```

启动后打开 <http://localhost:38886>。bb 托管的运行状态默认存放在 `~/.bb/`。

在另一个终端停止正在运行的实例：

```bash
bb-app stop
```

`bb` CLI 面向已经运行的 server（默认 `http://127.0.0.1:38886`）：

```bash
bb status
bb guide
```

bb 复用本机已认证的 provider CLI（Claude Code、Codex、Pi 等）。当前本机已有 Codex、Pi / Oh My
Pi、OpenCode 等用户级安装，且 `bb-app` 自带 `@earendil-works/pi-coding-agent`
依赖，无需为 bb 单独配置 provider 凭证。

## 遥测

生产运行（`bb-app`
launcher）会发送匿名使用遥测（启动次数、线程创建数、用户消息数），只带随机安装 id，不含项目路径或消息内容。需要关闭时设置环境变量：

```bash
BB_TELEMETRY=false bb-app
```

## 更新与回滚

更新到最新稳定版：

```bash
npm install -g bb-app@latest
```

bb 也提供 `bb updates`
查看和应用更新；由于安装来源是用户级 npm，直接用上面的 npm 命令更新即可，与更新 OpenCode 的方式一致。nightly 通道对应
`bb-app@nightly`，不建议默认使用。

回滚或完全移除：

```bash
npm uninstall -g bb-app
rm -rf ~/.bb   # 只在确认不再需要 bb 数据时执行
```

## 验证记录

2026-08-14 安装后验证：

- `bb --version` 返回 `0.37.0`。
- `bb-app`（`BB_TELEMETRY=false`）启动后监听 38886，`/` 与 `/api/health` 均返回 200。
- `bb status` 能连接运行中的 server，显示数据目录 `~/.bb`。

## 参考

- [bb GitHub 仓库](https://github.com/get-bb/bb)
- [bb-app npm 包](https://www.npmjs.com/package/bb-app)
- [bb-app 包文档](https://github.com/get-bb/bb/blob/main/packages/bb-app/README.md)
