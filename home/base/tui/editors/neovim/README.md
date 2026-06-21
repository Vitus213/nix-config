# Neovim

当前 Neovim 配置基于 [AstroNvim](https://github.com/AstroNvim/AstroNvim)。更多基础用法见
[AstroNvim 文档](https://astronvim.com/)。

## 截图

![](/_img/astronvim_2023-07-13_00-39.webp)

## 配置结构

| 内容                        | 标准位置                    | 当前方式                |
| --------------------------- | --------------------------- | ----------------------- |
| Neovim 配置                 | `~/.config/nvim`            | 本目录下的 `nvim/`      |
| 插件目录                    | `~/.local/share/nvim`       | 由 lazy.nvim 生成和管理 |
| LSP、DAP、linter、formatter | `~/.local/share/nvim/mason` | 由 `default.nix` 安装   |

## 插件更新

lazy.nvim 不会自动更新插件，需要手动执行:

```vim
:Lazy update
```

清理无用插件:

```vim
:Lazy clean
```

## 常用快捷键

### Tree-sitter 增量选择

| 动作              | 快捷键         |
| ----------------- | -------------- |
| 开始选择          | `<Ctrl-space>` |
| 扩大到下一个 node | `<Ctrl-space>` |
| 扩大到 scope      | `<Alt-Space>`  |
| 缩小选择          | `Backspace`    |

### 搜索和跳转

由 [flash.nvim](https://github.com/folke/flash.nvim) 提供增强搜索。

| 动作            | 快捷键                    |
| --------------- | ------------------------- |
| 普通搜索        | `/`                       |
| Flash 搜索      | `s`                       |
| Treesitter 搜索 | `yR` / `dR` / `cR` / `vR` |
| Remote Flash    | `yr` / `dr` / `cr`        |

### 文件和 LSP

| 动作           | 快捷键         |
| -------------- | -------------- |
| 打开文件树     | `<Space> + e`  |
| 定位当前文件   | `<Space> + o`  |
| 切换自动换行   | `<Space> + uw` |
| 显示当前行诊断 | `gl`           |
| 显示符号信息   | `K`            |
| 查找引用       | `gr`           |
| 下一个 buffer  | `]b`           |
| 上一个 buffer  | `[b`           |

### 窗口和 buffer

| 动作         | 快捷键                        |
| ------------ | ----------------------------- |
| 水平分屏     | `\`                           |
| 垂直分屏     | `\|`                          |
| 关闭 buffer  | `<Space> + c`                 |
| 窗口间移动   | `<Ctrl> + h/j/k/l`            |
| 调整窗口大小 | `<Ctrl> + Up/Down/Left/Right` |

macOS 上这些快捷键可能和 Mission Control 冲突，需要在系统设置里关闭对应快捷键。

### 编辑和格式化

| 动作                           | 快捷键         |
| ------------------------------ | -------------- |
| 切换当前 buffer 自动格式化     | `<Space> + uf` |
| 格式化文档                     | `<Space> + lf` |
| Code action                    | `<Space> + la` |
| 重命名                         | `<Space> + lr` |
| 打开 LSP symbols               | `<Space> + lS` |
| 注释当前行或选区               | `<Space> + /`  |
| 打开光标处路径或 URL           | `gx`           |
| 按文件名查找                   | `<Space> + ff` |
| 按文件名查找，包含隐藏文件     | `<Space> + fF` |
| ripgrep 搜索内容               | `<Space> + fw` |
| ripgrep 搜索内容，包含隐藏文件 | `<Space> + fW` |

### Git

| 动作             | 快捷键         |
| ---------------- | -------------- |
| 仓库 commits     | `<Space> + gc` |
| 当前文件 commits | `<Space> + gC` |
| branches         | `<Space> + gb` |
| status           | `<Space> + gt` |

### Session

| 动作                 | 快捷键         |
| -------------------- | -------------- |
| 保存 session         | `<Space> + Ss` |
| 加载上次 session     | `<Space> + Sl` |
| 删除 session         | `<Space> + Sd` |
| 搜索 session         | `<Space> + Sf` |
| 加载当前目录 session | `<Space> + S.` |

### 全局查找替换

打开 spectre.nvim:

```text
<Space> + ss
```

命令行方案:

```bash
fd "\\.nix$" . | sad '<pattern>' '<replacement>' | delta
```

### Surround

由 mini.surround 提供，前缀是 `gz`。

| 动作               | 示例     |
| ------------------ | -------- |
| 给当前 word 加引号 | `gzaiw'` |
| 删除外层引号       | `gzd'`   |
| 把单引号换成双引号 | `gzr'"`  |
| 高亮外层引号       | `gzh'`   |

### 其他

| 动作            | 快捷键         |
| --------------- | -------------- |
| treesj 智能合并 | `<Space> + j`  |
| treesj 智能拆分 | `<Space> + s`  |
| Yank 历史       | `<Space> + yh` |
| Undo 历史       | `<Space> + uh` |
| 当前文件路径    | `:!echo $%`    |

## 参考

- [AstroNvim walkthrough](https://astronvim.com/Basic%20Usage/walkthrough)
- `nvim/lua/plugins/`
- 各插件自己的文档
