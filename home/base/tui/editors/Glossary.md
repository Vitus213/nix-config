# 编辑器术语

## LSP

LSP 是 Language Server Protocol，用于让编辑器和语言服务器之间用统一协议通信。

常见能力:

- 跳转定义
- 查找引用
- hover 信息
- 代码补全
- 错误和警告
- 重构
- 格式化入口

LSP 的目标是把语言智能从编辑器中拆出来，让同一个语言服务器可以服务多个编辑器。

参考:

- <https://en.wikipedia.org/wiki/Language_Server_Protocol>
- <https://langserver.org/>

## Tree-sitter

Tree-sitter 是 parser generator 和增量解析库。它能为源文件生成语法树，并在文件编辑时高效更新。

常见用途:

- 语法高亮
- 缩进
- 折叠
- 增量选择
- 单文件内的结构化编辑

Tree-sitter 通常只理解单个文件的语法结构，不理解整个项目的语义。函数是否真实存在、变量类型是什么、跨文件引用是否正确，这些通常交给 LSP。

参考:

- <https://tree-sitter.github.io/tree-sitter/>
- <https://www.reddit.com/r/neovim/comments/1109wgr/treesitter_vs_lsp_differences_ans_overlap/>

## LSP 和 Tree-sitter 的区别

- Tree-sitter: 轻量、快速，适合语法高亮、缩进、折叠、结构化选择
- LSP: 更重，理解整个项目语义，适合补全、诊断、跨文件跳转和重构

## Formatter 和 Linter

Formatter 只关心代码展示形式，例如缩进、换行和空格。`prettier` 是典型 formatter。

Linter 会分析代码并报告潜在错误或风格问题，例如建议把 `var` 改成 `let` / `const`。

多数 formatter 和 linter 都按文件处理，不一定需要理解整个项目。
