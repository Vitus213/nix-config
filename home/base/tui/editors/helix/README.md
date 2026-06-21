# Helix

Helix 是一个更有主见、内置能力更多的模态编辑器。当前主力编辑器仍是 Neovim，但 Helix 的设计对整理编辑器工作流很有参考价值。

## 入门

在 Helix 中运行:

```text
:tutor
```

## 和 Neovim 的主要差异

1. Helix 是先选择再执行动作
   - Helix: 先 `2w` 选择两个 word，再 `x` 删除
   - Vim / Neovim: 先 `d` 再 `2w`
2. Helix 内置 LSP、Tree-sitter、fuzzy finder、multi-cursor、surround 等能力
3. Helix 使用 Rust 从头实现，默认值更现代，没有 VimScript / Lua 配置层
4. Neovim 插件生态更成熟，Helix 插件系统仍在演进
5. Helix 没有内置终端，更推荐搭配 Zellij、tmux、Kitty 或 WezTerm
6. Helix 没有传统 tree-view，通常搭配 Yazi、ranger、Broot 或内置 file picker

## 当前结论

把 Helix / Neovim 放在终端文件管理器和 Zellij 工作流里使用，是更稳定的方向。它和过去 VSCode /
JetBrains 式的工作流不一样，但能减少编辑器内部承担过多终端和文件管理职责的问题。

参考:

- <https://github.com/helix-editor/helix/discussions/6356>
- <https://github.com/helix-editor/helix/issues/1976>
- <https://github.com/helix-editor/helix/pull/8675>
