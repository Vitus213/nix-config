# 工作区栏高亮约定调研

调研日期：2026-11-10。仅调研、读取公开源码和仓库配置；未修改桌面配置，未运行构建、测试或格式化。

本文保留 2026-11-10 的 v4 与社区调研快照；其中“本仓库”“当前”均指调查当时。v5 声明配置与本轮验证状态见
[Noctalia v5](./noctalia-v5.md)。

## 结论

**不要把“当前选中、有窗口、请求注意”做成三个同等显眼的彩色胶囊。** 推荐把三个问题分开编码：

- **我在哪：** focused 使用唯一的强调色实心背景，并保留独立的形状或边线标记。
- **哪里有窗口：** occupied 使用中性文字、小点或轻描边，不再使用第二个高饱和强调色。
- **哪里需要处理：** urgent 使用独立的小角标、侧边线或
  `!`，红色只服务于请求注意，不替换“当前位置”的标记。
- **其他显示器显示哪里：** active-but-not-focused 用细下划线；不能冒充全局 focused。
- **哪里是空位：** empty 降低对比度，或隐藏；当前 focused 即使为空也保留当前位置标记。

这是基于下述官方状态模型及社区样本提出的设计建议，不是统计意义上的“多数用户都这样配置”。两个社区样本展示了形状与单色高亮的取舍，也都有语义缺口，不能整份照搬。

## 一、先明确状态：active 不等于 occupied

Waybar 的官方 `niri/workspaces` 文档定义如下；实现为每项独立设置 CSS class，而非互斥的枚举。[W1][W2]

| 状态              | 官方含义                                        | 设计含义                                 |
| ----------------- | ----------------------------------------------- | ---------------------------------------- |
| `.focused`        | 全局唯一聚焦工作区                              | 键盘当前所在位置                         |
| `.active`         | 在其所属输出上可见的工作区                      | 多屏可以同时存在多个；不是“里面有应用”   |
| `.urgent`         | 包含一个或多个 urgent 窗口                      | 请求用户注意；不是“有未读消息”的通用接口 |
| `.empty`          | 工作区为空；实现检查 `active_window_id == null` | 非 `.empty` 才对应本次讨论的 occupied    |
| `.current_output` | 工作区属于当前这条 bar 的输出                   | 所属显示器，不是 focused                 |

**证据：** `Workspace::update()` 分别设置 focused、active、urgent、empty，所以
`.focused.active`、`.focused.empty`、`.active.urgent` 等组合需要独立考虑；不能用一个通用 `.active`
样式覆盖全部语义。[W2]

**容易漏掉的实现细节：** 截至本次读取的 Waybar 提交，`format-icons` 选择顺序是
`urgent → active → focused → empty → 工作区名 → index → default`。同时设置 active 和 focused 图标时，若一个工作区同时 active/focused，会先取 active 图标。CSS
class 不受这个图标选择顺序限制，因此建议用 CSS 明确区分 focused 与 active，而不要仅靠两个 state
icon。[W3]

**可见性不是高亮：** `all-outputs` 默认 false；`hide-empty` 默认 false；`current-only`
默认 false。隐藏空位会改变栏中可见的导航目标，不会把 occupied 变成 active。实现中的 `hide-empty`
会保留 focused 空工作区；`display-condition=only-populated`
在过滤阶段保留 active 工作区。不同选项的边界不要凭名字混为一谈。[W1][W2][W3]

## 二、Noctalia v4 默认到底做了什么

### 版本边界

本仓库使用的是 QML / settings.json 形式的 Noctalia v4 工作区组件。公开仓库现名为
`noctalia-dev/noctalia`，v4 源码在 `legacy-v4` 分支；本文将 v4 来源固定在
`f6c7c01bb3023e290a91fed130810f623fcdcc06`，不拿新版 main 的配置体系回答旧版问题。[N1][N2]

### 默认设置与当前仓库对比

默认值来自上游 `BarWidgetRegistry.qml`，不是从截图反推。[N1] 本仓库配置见
[`settings.json`](../home/linux/gui/base/noctalia/config/settings.json)。

| 项目                         | Noctalia v4 默认 | 当前仓库    | 实际影响                                                            |
| ---------------------------- | ---------------- | ----------- | ------------------------------------------------------------------- |
| `labelMode`                  | `index`          | `index`     | 显示 `ws.idx`，不是命名工作区名中的数字前缀 [N2]                    |
| `focusedColor`               | `primary`        | `primary`   | 聚焦使用主题 primary                                                |
| `occupiedColor`              | `secondary`      | `secondary` | 非聚焦且有窗口时使用主题 secondary                                  |
| `emptyColor`                 | `secondary`      | `secondary` | 空胶囊背景额外乘 0.3 alpha [N2]                                     |
| `hideUnoccupied`             | false            | true        | 当前仅显示有窗口或 focused 的工作区 [N3]                            |
| `showLabelsOnlyWhenOccupied` | true             | true        | 有窗口或 focused 才显示数字；空位可能只有胶囊 [N2]                  |
| `pillSize`                   | 0.6              | 0.6         | 基础尺寸，不是取消选中拉长的开关 [N3]                               |
| `showApplications`           | false            | false       | 使用普通 pill，而不是应用分组模式                                   |
| `showBadge`                  | true             | true        | 设置界面仅在应用分组模式显示此项；不是普通 pill 的 urgent 开关 [N4] |

普通 pill 的**背景和文字优先级完全相同**：[N2]

```text
hover → focused → urgent → occupied → empty
```

- hover 使用 `mHover / mOnHover`，会暂时覆盖 focused 和 urgent 配色。
- focused 使用配置的 focusedColor。
- urgent 使用硬编码的主题 `mError / mOnError`，没有独立的 `urgentColor` 配置项。
- occupied 使用配置的 occupiedColor。
- empty 使用 emptyColor，背景 alpha 为 0.3。

**形状是另一条判断链：** pill 拉长看 `workspace.isActive`，不是
`isFocused`；工作区尺寸计算使用 active 因子 2.2，但有标签时还会考虑文字宽度，所以不应把截图宽度机械解释成恰好 2.2 倍。多屏上可以出现“拉长但不是全局聚焦色”的工作区。[N2][N3]

### 对截图的解释边界

用户描述“1 蓝色拉长、2 红色、6 灰色”与源码的以下情况相容：

- `1` 同时 active/focused，呈强调色并拉长。
- `2` 非 focused 且 urgent，呈 error 色。
- `6` 非 focused、非 urgent、但 occupied，呈 secondary 色。

**这些是条件解释，不是已证明的运行时状态。**
hover、主题实际色值、IPC 缓存都能影响观察；仅凭红色不能断言 `is_urgent=true`。本仓库已有
[urgent 状态不同步调查](noctalia-workspace-urgent.md)，其中记录了历史 IPC 增量事件遗漏及修补；这份历史记录不等于本次截图已经复现同一问题。

特别是当前
`hideUnoccupied=true`，普通空工作区按组件条件不会显示；因此“灰色的 6”不能仅凭灰色就归为 empty。当前
`useWallpaperColors=true` 也意味着 primary/secondary 是主题语义角色，不应被当成永远固定的蓝/灰常量。

## 三、可核实社区 dotfiles：两个不同方向

### 样本 A：nfoert/niri-dotfiles——形状加低彩度背景

固定提交：`b42aa9186f765639f60a8e00bf1367ba50c25523`。[C1][C2]

```json
"niri/workspaces": {
  "format": "{icon}",
  "format-icons": {
    "active": "",
    "default": ""
  }
}
```

其 CSS 对 `.focused` 和 `.active` 使用同一灰色背景 `rgb(69, 71, 87)`、白字；默认白字。[C2]

- **可借鉴：** 实心与空心图标提供非纯色通道；整体不用三四种高饱和色争夺注意力。
- **不能照搬：**
  这里实心对应 active，而 default 不等于 empty；非 active 但有窗口的工作区仍走 default。CSS 也没有单独的 occupied/empty/urgent 样式，且把 active 与 focused 画成相同背景。因此它并没有完整解决本任务的三状态区分。[C1][C2][W1]

### 样本 B：vaelixd/niri-dotfiles——单点、只换颜色

固定提交：`99f4f4c3d7c5de5c4291f559715683bf276c37e7`。[C3][C4]

```json
"niri/workspaces": {
  "format": "{icon}",
  "format-icons": { "default": "" }
}
```

其默认工作区按钮为紫色 `#bd93f9`，`.active` 改为
`#b4befe`；未在该 stylesheet 为 focused/urgent/empty 分别指定样式。hover 还将按钮前景设为 transparent。[C4]

- **可借鉴：** 占用空间很小，视觉简洁。
- **不推荐直接采用：**
  同形图标加相近颜色，缺少非颜色信号；多屏 active/focused 不可区分，也没明确表达占用或紧急状态。hover 隐藏图标更不适合作为稳定导航标记。[C3][C4]

### 对比摘要

| 方案             | 当前位置                                 | 有窗口              | 紧急             | 主要取舍                                                 |
| ---------------- | ---------------------------------------- | ------------------- | ---------------- | -------------------------------------------------------- |
| Noctalia v4 默认 | primary + active 拉长                    | secondary 实心 pill | error 实心 pill  | 有形状冗余，但占用与紧急都占据整块背景，hover 又覆盖状态 |
| nfoert           | active 实心图标 + 灰背景；focused 同背景 | 没有单独区分        | 未单独配置       | 比纯色更有形状提示，但状态覆盖不完整                     |
| vaelixd          | active 点变色                            | 没有单独区分        | 未单独配置       | 紧凑但主要依赖色差                                       |
| 本文推荐         | focused 唯一强调填充；active-only 下划线 | 中性数字/小点       | 独立角标或侧边线 | 状态叠加，不让 urgent 抹掉当前位置                       |

前两份是可核实的实际配置样本，不代表社区采用率；上游 Waybar 提供的是状态接口，不规定哪套主题为唯一“官方默认美术”。[W1][C1–C4]

## 四、推荐方案：先状态语义，再选色

### A. 只用 Noctalia 现有设置：最小可达方案

以下仅为候选片段，**没有写入配置或运行验证**；不是完整 settings.json：

```json
{
  "id": "Workspace",
  "focusedColor": "primary",
  "occupiedColor": "none",
  "emptyColor": "none",
  "hideUnoccupied": true,
  "showApplications": false
}
```

- 保留 focused 的 primary；占用/空位回到主题中性色，减少第二个强调色造成的“两个都像被选中”。
- `none` 是上游颜色选择模型支持的键；**这里不表示透明或禁用**。颜色解析会落到
  `mOnSurface`，对应文字为 `mSurface`；普通 occupied
  pill 仍是完整实心反色块，不能把它描述成已经实现“淡底小点”。[N5][N6]
- 保留 `hideUnoccupied=true`、当前标签可见条件和工作区排列，不把高亮修正扩大为导航布局改造。
- 不把 occupiedColor 改成 error；urgent 的红色只留给请求注意。
- **局限：**
  该片段不会取消 active 拉长，不会改变 hover 优先级，不会把 urgent 红底改成小点或细边。这些不是继续换 primary/secondary 就能解决的问题。[N2][N3]

若主题的 `mOnSurface` 过亮，`none`
仍可能比 primary 更抢眼；应依据实际主题观察决定是否采用，而非把这个片段当作已验证的最终答案。若要求所有非当前工作区都严格低强调，进入方案 B，不能承诺仅 settings 能完成。

**可选的标签纠正，不与高亮改动捆绑：** 设置 `labelMode="name"`、`characterCount=1`
在源码上可行：`WorkspacePill.qml` 的 name 分支直接返回
`workspace.name.substring(0, characterCount)`；尺寸计算也按该标签计算。[N2][N3] 对本仓库命名的
`1terminal`…`9file`、`0other`，结果分别为 `1`…`9`、`0`，与数字快捷键一致，而 `index`
显示的是运行时顺序。它不重命名、不重排工作区，不改变 `hideUnoccupied`；没有名字的工作区仍回退到
`ws.idx`。因此“一字符名称”依赖继续遵守名称首字符唯一的约定，而不是一种通用编号修复。

### B. 组件级方案：真正分离形状、占用与紧急

这是建议的交互规格，**本次不实施组件补丁，也不迁移到 Waybar**：

| 组合                 | 背景/文字                   | 独立标记                                               |
| -------------------- | --------------------------- | ------------------------------------------------------ |
| focused + occupied   | 唯一 primary 实心，反色文字 | 保留现有 active 拉长                                   |
| focused + empty      | 保留相同 focused 高亮       | 不因“空”而消失                                         |
| active + 非 focused  | 低强调中性背景/文字         | 保留现有 active 拉长，明确它只代表本屏可见             |
| 非 active + occupied | 低强调中性数字/底色         | 如需占用标记，用小点或轻描边                           |
| 非 focused + empty   | 保留现有隐藏策略            | 不增加新的固定槽位                                     |
| 非 focused + urgent  | 保留 occupied 的低强调底色  | 叠加 error 色小点、`!` 或细边，取消整块红底            |
| focused + urgent     | 仍保留 focused 主色         | 按真实状态决定是否保留小角标，不修改或伪造 urgent 数据 |
| hover                | 轻描边或轻微亮度变化        | 不覆盖 focused 主色、不抹掉 urgent 小标记              |

建议补丁只改状态呈现，不改工作区来源、过滤、排列、点击范围和 active 尺寸动画。urgent 小标记应始终跟随真实
`isUrgent`；若 IPC 状态卡住，应修数据同步，不能为了让红色消失而在组件里假清除。这样把“我在哪”和“哪里请求注意”分离，同时不混入位置与布局改造。

Waybar 对应落点为
`.focused`、`.active:not(.focused)`、`:not(.empty)`、`.empty:not(.focused)`、`.urgent`；这些是样式选择目标，不是可直接复制进 Noctalia 的配置项。urgent 只覆盖角标/边线等专属通道，避免 CSS 顺序使
`.urgent` 的整块背景覆盖 `.focused`。官方多 class 实现允许这种叠加。[W1][W2]

### 评估顺序

1. 先以运行时 focused/active/occupied/urgent 值确认状态同步，不通过换色掩盖错误 urgent。
2. 鼠标移出工作区栏再判断，排除 Noctalia hover 的优先级干扰。
3. 先验收单屏：当前位置唯一、占用低强调、紧急独立；再验收多屏 active 与 focused 的差异。
4. 最后才调颜色、圆角、动画和 pillSize。颜色数量减少不是目的，**每个视觉通道只承担一个清晰问题**才是目的。

以上是后续评估建议，本次没有执行运行时验证。

## 来源

### 官方

- [N1：Noctalia v4 工作区默认值，BarWidgetRegistry.qml](https://github.com/noctalia-dev/noctalia/blob/f6c7c01bb3023e290a91fed130810f623fcdcc06/Services/UI/BarWidgetRegistry.qml#L294-L313)
- [N2：Noctalia v4 普通 pill，状态、hover、标签与形状](https://github.com/noctalia-dev/noctalia/blob/f6c7c01bb3023e290a91fed130810f623fcdcc06/Modules/Bar/Extras/WorkspacePill.qml)
- [N3：Noctalia v4 Workspace.qml，尺寸计算与过滤](https://github.com/noctalia-dev/noctalia/blob/f6c7c01bb3023e290a91fed130810f623fcdcc06/Modules/Bar/Widgets/Workspace.qml)
- [N4：Noctalia v4 WorkspaceSettings.qml，公开设置与 showBadge 可见条件](https://github.com/noctalia-dev/noctalia/blob/f6c7c01bb3023e290a91fed130810f623fcdcc06/Modules/Panels/Settings/Bar/WidgetSettings/WorkspaceSettings.qml)
- [N5：Noctalia v4 Color.qml，颜色解析与 colorKeyModel](https://github.com/noctalia-dev/noctalia/blob/f6c7c01bb3023e290a91fed130810f623fcdcc06/Commons/Color.qml#L305-L395)
- [N6：Noctalia v4 NColorChoice.qml，颜色选择控件](https://github.com/noctalia-dev/noctalia/blob/f6c7c01bb3023e290a91fed130810f623fcdcc06/Widgets/NColorChoice.qml)
- [W1：Waybar niri/workspaces 官方 manpage](https://github.com/Alexays/Waybar/blob/ecbd887aa8ce9f88525805e1df4c062003e87f91/man/waybar-niri-workspaces.5.scd)
- [W2：Waybar Workspace::update，CSS classes 与可见性](https://github.com/Alexays/Waybar/blob/ecbd887aa8ce9f88525805e1df4c062003e87f91/src/modules/niri/workspace.cpp)
- [W3：Waybar Workspaces::getIcon 与列表过滤](https://github.com/Alexays/Waybar/blob/ecbd887aa8ce9f88525805e1df4c062003e87f91/src/modules/niri/workspaces.cpp)

### 社区

- [C1：nfoert/niri-dotfiles，Waybar config](https://github.com/nfoert/niri-dotfiles/blob/b42aa9186f765639f60a8e00bf1367ba50c25523/waybar/config)
- [C2：nfoert/niri-dotfiles，Waybar style.css](https://github.com/nfoert/niri-dotfiles/blob/b42aa9186f765639f60a8e00bf1367ba50c25523/waybar/style.css)
- [C3：vaelixd/niri-dotfiles，Waybar config](https://github.com/vaelixd/niri-dotfiles/blob/99f4f4c3d7c5de5c4291f559715683bf276c37e7/waybar/config)
- [C4：vaelixd/niri-dotfiles，Waybar style.css](https://github.com/vaelixd/niri-dotfiles/blob/99f4f4c3d7c5de5c4291f559715683bf276c37e7/waybar/style.css)
