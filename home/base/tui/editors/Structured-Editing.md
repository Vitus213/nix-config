# 结构化编辑

## S-expression / Lisp

可选方案:

- paredit /
  [lispy](https://github.com/doomemacs/doomemacs/tree/master/modules/editor/lispy): 能力强，但复杂度高
- [evil-cleverparens](https://github.com/emacs-evil/evil-cleverparens): 简单实用
- [parinfer](https://shaunlebron.github.io/parinfer/): 现代、简洁，但可能和部分补全插件冲突

如果启用 parinfer，建议在 Lisp mode 中关闭 sexp / smartparens 一类插件，避免行为互相覆盖。

## Neovim

- [parinfer-rust](https://github.com/eraserhd/parinfer-rust)
- [conjure](https://github.com/Olical/conjure)

## Helix

- [parinfer #4090](https://github.com/helix-editor/helix/discussions/4090)

## 其他语言

非 Lisp 语言主要依赖 Tree-sitter 提供结构化选择、缩进和一部分结构化编辑能力。
