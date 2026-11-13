# Linux 中文字体选型调研

调研日期：2026-11-13。本次只调查，不修改字体、应用设置或显示缩放。

## 本机现状

通过实际 `fc-match` 查询（中文加 `lang=zh-cn:charset=4e2d`），当前匹配为：

| 用途                        | 当前结果                                 |
| --------------------------- | ---------------------------------------- |
| 西文 sans-serif             | Source Sans 3                            |
| 中文 sans-serif / system-ui | LXGW WenKai Screen（霞鹜文楷屏幕阅读版） |
| 中文 serif                  | Source Han Serif SC（思源宋体）          |
| 中英文 monospace            | Maple Mono NF CN                         |

`modules/nixos/desktop/fonts.nix`
的 sansSerif 列表把文楷放在思源黑体之前；这只是 Fontconfig 的泛型分类，不会把楷体字形变成无衬线。全局抗锯齿开启，hinting 关闭。Niri 现场缩放为约 124.17%；不能不做对照就把模糊单独归因于字体或某个渲染设置。

用户明确偏好中文楷体，不希望为了处理发虚而直接更换成黑体。

## 字体项目的一手定位

### 霞鹜文楷屏幕阅读版

[官方说明](https://github.com/lxgw/LxgwWenKai-Screen/blob/main/Readme.md)明确：原版文楷 Regular 在 PC/Android 屏幕上偏细，因此屏幕版把原版 Medium 的字重属性标为 Regular，并调整度量。当前系统已经使用面向此场景的 Screen 版，不能把换回普通 Regular 当作增粗修复。官方对 macOS 另有显示模糊警告，不能把该警告直接套用到本机 Linux。

适合：偏好楷体的中文界面、聊天与阅读。是否觉得舒服仍取决于字号、行距和显示环境。

### Maple Mono NF CN

[稳定 v7 官方说明](https://github.com/subframe7536/maple-font/blob/v7/README_CN.md)定位为编码等宽字体；CN 版基于资源圆体覆盖中日韩字符，中英文宽度 2:1，便于代码和 Markdown 表格对齐。它的中文不是文楷风格。

适合：终端与代码。用户若要求代码中文也必须是楷体，应单独比较文楷的等宽款，不应把普通比例字体直接替换所有等宽用途。

## 对当前系统的建议

不建议因微信、Delta 两个应用的问题整体更换字体包。现有字体分工已有明确用途，优先处理应用自己的选择与回退：

- 保留中文界面/聊天的文楷屏幕版，并在不遵循系统字体的应用中明确选择它。
- 西文界面可继续使用 Source Sans 3；它不包含中文，不应被当作中文方案。
- 代码/终端继续使用有完整中文的等宽字族；Maple Mono NF CN 可避免只指定 JetBrains
  Mono 后再由应用猜中文回退。
- 思源宋体适合刻意选择的宋体阅读，但不应作为混乱回退的偶然结果。
- hinting、字重、字号和分数缩放应分别对照，不全局盲目叠加补丁；安装更多字体也不能代替修正 Delta 的配置。

Delta 现场配置把 UI、正文和代码都指定为 JetBrainsMono Nerd Font Mono；日志明确出现回退到 Source Han
Serif。系统中文默认匹配文楷不代表 Delta 已使用文楷。该调查尚未修改 Delta 设置。

## 社区样本的使用边界

公开 dotfiles 与讨论只能证明某作者在某个用途选择过某字族，不能据搜索排名、仓库 stars 或少数配置推算市场占有率。“适合用户”需要同时考虑其楷体偏好、阅读/编码用途及实际渲染。

## 已核对的社区实例

| 作者/环境                    | 实际用法                                                                  | 来源                                                                                                                                                                                                                |
| ---------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ryan4yin / NixOS             | Source Sans 3 搭配文楷 Screen；中文黑体仅后备；等宽首选 Maple Mono NF CN  | [固定配置](https://github.com/ryan4yin/nix-config/blob/c44aa91e/modules/nixos/desktop/fonts.nix)                                                                                                                    |
| emoeem / Arch、Wayland、Niri | 界面 MiSans；衬线链用臻楷、文楷 Screen；等宽 Maple Mono Normal NF CN      | [固定配置](https://github.com/emoeem/fontconfig/blob/13e026c60ba3de44abefe136b0cb3d66dde96acf/fonts.conf)、[用途说明](https://github.com/emoeem/fontconfig/blob/13e026c60ba3de44abefe136b0cb3d66dde96acf/README.md) |
| wenjinnn / NixOS             | 界面 Ubuntu + Sarasa UI SC；等宽 CaskaydiaCove + Sarasa Mono SC           | [固定配置](https://github.com/wenjinnn/.dotfiles/blob/c7715a64d564fd4a809f5e02d777b4b605b42c09/modules/nixos/fonts.nix)                                                                                             |
| ManJack1 / NixOS             | 中文界面 Noto Sans CJK SC，衬线 Noto Serif CJK SC；安装文楷不等于设为默认 | [固定配置](https://github.com/ManJack1/NixOS/blob/c7b85f6d9ca898fe6f8bcebe377ea04b08394db1/modules/system/fonts.nix)                                                                                                |
| Arelia / Arch 中文论坛       | 无衬线 Sarasa Gothic SC、等宽 Sarasa Mono SC、衬线思源宋体                | [本人贴出的配置](https://forum.archlinuxcn.org/t/topic/15960/1)                                                                                                                                                     |

这些样本展示不同取舍，不构成使用率排行；其中 ryan4yin 的组合与当前仓库非常接近，不能把相似配置重复计为独立流行度证据。

[更纱官方说明](https://github.com/be5invis/Sarasa-Gothic#what-are-the-names)区分 UI/Gothic 与 Mono/Term/Fixed，不能只报“更纱”而不说明用途。[Noto CJK 官方仓库](https://github.com/notofonts/noto-cjk)也区分语言地区版本；中文默认宜明确 SC，不应让应用偶然选到其他地区字形。

## 版本与变体注意事项

- 文楷 Screen 的 Regular 已使用普通文楷 Medium 的笔画粗细，不应因标签是 Regular 就盲目统一加粗。普通文楷 Regular 可作同风格的细字重对照，但不是当前“发虚”的既定修复。
- 普通 Screen 不等于 Mono
  Screen；当前 Nix 包安装的是普通 Screen。若用户连代码中文也要求楷体，需单独评估文楷等宽款的编码体验，不能把现有 Maple 中文误称为文楷。
- Maple v7 基础字体有可变版本，但 CN / NF CN 是静态字重，不能把开发分支的 v8 特性写成本机已经具备。
- 文楷 Screen 没有对某个字号、分数缩放或渲染器作清晰度保证；推荐保留是基于用户偏好与用途，而非承诺换字体即可消除模糊。

变体依据：[文楷普通版](https://github.com/lxgw/LxgwWenKai)、[Screen 1.522 发布说明](https://github.com/lxgw/LxgwWenKai-Screen/releases/tag/v1.522)、[Maple 稳定 v7](https://github.com/subframe7536/maple-font/blob/v7/README_CN.md)。
