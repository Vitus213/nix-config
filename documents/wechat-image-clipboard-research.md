# 微信图片粘贴：xwayland-satellite 与 Qt 剪贴板研究

调研日期：2026-11-11。最初调查对象为 NixOS、Niri 26.04、xwayland-satellite 0.8.3、WeChat
4.1.1.4 的 xcb/bubblewrap 组合。下文保留调查时的证据与候选方案，不代表最终部署设置。用户随后明确选择新版微信直接运行、取消沙箱和路径隔离；当前配置以
[Linux 微信、QQ 与飞书](./linux-im-apps.md)
为准。上游资料与现场采样均区分源码事实、现场事实和未验证推断。

## 结论

1. **不能把本次故障概括为“Wayland 图片没有桥接到 X11”。** 同一现场剪贴板的 Wayland 与 X11
   PNG 读取结果 SHA-256 完全相同；X11 已能取到有效图片。它不是只有 `wl-paste --list-types`
   声明了格式、却没有实际数据的情况。
2. **不能把 `TARGETS` 只列出 `image/png` 解释成“Qt 必须的 `application/x-qt-image` 丢失”。** 标准 Qt
   XCB 会将其识别为图像，并在 Qt 内部合成 `application/x-qt-image`；现场 Qt 6.11.2
   XCB 探针已成功读取非空 520×51 图像。[Qt 内部转换源码](https://github.com/qt/qtbase/blob/v6.11.2/src/gui/kernel/qinternalmimedata.cpp)
3. **`TARGETS` 列表没有列出 `TARGETS`，不等于桥接器不能响应 `TARGETS` 请求。** 0.8.3 有专门的
   `TARGETS` 响应分支，但只返回所桥接的 MIME atoms，未额外补入协议元目标。`TIMESTAMP` / `MULTIPLE`
   没有相应的专门服务分支；这是实现边界，却尚无证据说明它触发了本次微信故障。[卫星源码](https://github.com/Supreeeme/xwayland-satellite/blob/v0.8.3/src/xstate/selection.rs)
4. **现有证据把排查重点缩小到微信客户端的粘贴入口、格式判断及其打包运行环境，而未确定具体根因。**
   故障时段的卫星日志出现 `TARGETS` / `UTF8_STRING`，未见微信对应的 PNG 读取；首次 `image/png`
   请求来自诊断用
   `xclip`。这与“PNG 已被请求、但桥接传输失败”不同。日志尚需 requestor→进程归属和一次完整受控操作才能进一步定责。
5. **“微信只支持文件 URI”“微信自带 Qt/插件与系统 Qt 不同”“微信缓存/焦点状态导致未走图像分支”都只是候选。**
   未取得微信该版本的官方剪贴板实现或等价的直接行为证据，不能写成根因；标准 Qt 探针成功也不能代替微信自身验收。

## 1. 本次现场证据及其边界

以下为主代理在同次调查中提供的结果，本研究子任务没有重复执行探针。

| 采样                                                                                 | 结果                                                                                                                    | 能证明什么／不能证明什么                                                                                                          |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `wl-paste --list-types`                                                              | `image/png`                                                                                                             | Wayland 声明提供 PNG；单凭此项还不能证明可读、可解码。                                                                            |
| `xclip -selection clipboard -o -t TARGETS`                                           | 只列 `image/png`                                                                                                        | X11 已成功执行 `TARGETS` 转换，并得到 PNG target；不能据此说 `TARGETS` 请求本身不受支持。                                         |
| Wayland 与 X11 分别读取 PNG 并计算 SHA-256                                           | 均为 `1f67da14b4d7e28a9a47eafbf0846781ebdcefe2ddb44f49e0033b04af5bc154`                                                 | 此时这张图的跨协议字节传输一致；不能外推所有会话时刻、所有图像尺寸都正常。                                                        |
| 图像识别                                                                             | 有效 8-bit PNG，520×51，5146 bytes                                                                                      | 当前样本不是空数据或已损坏图像；不符合“大图传输达到某阈值才失败”的典型条件。                                                      |
| 标准 Qt 6.11.2，`xcb`，创建并 `show()` 一个 QWidget，事件循环运行约 1.2 秒后读剪贴板 | `formats=['image/png','application/x-qt-image']`，`hasImage=True`，图像 520×51，`null=False`                            | 该现场的标准 Qt XCB 路径能枚举、识别并解码 PNG；不是微信进程内部的探针。                                                          |
| 未映射窗口的早期 Qt 探针                                                             | formats 为空                                                                                                            | 不能把它当作图像兼容失败；映射/焦点与事件处理条件不同，后续有效探针已成功。                                                       |
| 17:02–17:07 卫星日志                                                                 | `Clipboard set from Wayland` 后有 `TARGETS`、`UTF8_STRING` 请求，未见 `image/png`；17:09:04 首次 PNG 请求是诊断 `xclip` | 采样更像客户端尚未进入取图分支，不是已观察到的 PNG 传输失败。但日志中其他客户端也能请求剪贴板，不应把所有 UTF8 请求直接归给微信。 |

这组证据不要求先重启卫星。重启会丢失原现场，并影响同实例的 X11 客户端；在已经能读到同字节 PNG 时，不能仅因存在上游剪贴板 issue 就把重启或换桥接器当成已证实修复。

## 2. xwayland-satellite 0.8.3 实际做了什么

### 2.1 图片不是“不支持的类型”，桥接也不是图像转码器

0.8.3 的 `set_clipboard()` 把 Wayland offer 中每个 MIME 名直接 intern 成 X
atom，保存原 MIME；只对 UTF-8 纯文本增加 `UTF8_STRING`
别名，没有对图片做 PNG→JPEG、PNG→文件 URI 或 Qt 私有格式的转换。[`set_clipboard()`](https://github.com/Supreeeme/xwayland-satellite/blob/v0.8.3/src/xstate/selection.rs)

X11 客户端请求 `image/png` 时，桥接器找到该 target，向 Wayland
offer 请求原 MIME 的数据，再以原 target 类型写入 X property。Wayland 侧
`ForeignSelection::receive()`
从 offer 的 pipe 读取数据；这里没有必须把 PNG 保存为临时文件的步骤。[X11 请求处理](https://github.com/Supreeeme/xwayland-satellite/blob/v0.8.3/src/xstate/selection.rs)、[Wayland 数据读取](https://github.com/Supreeeme/xwayland-satellite/blob/v0.8.3/src/server/selection.rs)

因此，**原始 `image/png`
字节传输本身不需要把截图所在的宿主机路径暴露进微信沙箱**。若微信选择的是文件 URI 或自己先落盘的业务路径，则路径可见性另当别论；不能用这一点反推当前 raw
PNG 就需要解除 tmp/home 隔离。

### 2.2 目标列表与元目标是两件事

`SelectionData::handle_selection_request()`：

- 对 `TARGETS` 单独处理，返回 `mimes` 中各 target 的 atom，property 类型为 `ATOM`。
- 对其他请求，要求 target 存在于所桥接的 `mimes`；找不到即返回失败，并由调用方发送 property 为
  `NONE` 的 `SelectionNotify`。
- 该路径没有为 `TIMESTAMP`、`MULTIPLE` 增加独立处理；当 Wayland
  offer 只有 PNG 时，也不会自动把这些 target 加入列表。
- 因此 `xclip ... -t TARGETS` 只得到 `image/png`
  与源码一致；并不表示图片 target 有误或 TARGETS 查询失效。[实现](https://github.com/Supreeeme/xwayland-satellite/blob/v0.8.3/src/xstate/selection.rs)

这意味着某些依赖额外 X11 selection 行为的客户端可能存在兼容空间，**但本次没有观察到微信请求
`TIMESTAMP` / `MULTIPLE`
被拒绝，也没有找到微信官方材料说明其依赖这些目标**。不能把实现边界直接升级为当前故障根因。

### 2.3 不是普遍的“超过 64 KiB 就不能传图片”

该版本在 Wayland→X11 方向比较数据长度与 X server 最大请求容量；超出时启动
`INCR`，通过后续 property 事件发送数据。在 X11→Wayland 方向，源码也处理
`INCR`，并通过 FIFO 串行化请求，避免部分 X11 应用无法同时处理多个增量转换而挂起。[双向增量传输实现及注释](https://github.com/Supreeeme/xwayland-satellite/blob/v0.8.3/src/xstate/selection.rs)

可以讨论其并发/状态机边界，但不能将历史报告中不同方向、不同接收方的 64
KiB 现象泛化为本版本所有 PNG 的硬上限。当前 5146-byte 样本已经实际读出。

## 3. Qt 为什么能够只凭 `image/png` 识别图像

以现场探针对应的官方 **Qt v6.11.2**
为基准；同时核对 v6.8.0，相关基本机制也存在，但本笔记不把系统 Qt 版本推定为微信内置 Qt 版本。

### 3.1 XCB 层不会要求 TARGETS 列表包含自身

`QXcbClipboardMime::formats_sys()` 先检查 selection owner，再主动请求
`TARGETS`，遍历返回的 atoms 得到格式名。没有“必须同时列出 `TARGETS` / `TIMESTAMP` / `MULTIPLE`
才接受图片”的条件。读取具体格式时，`retrieveData_sys()`
从这些 atoms 中匹配所需格式，再执行转换请求。[Qt XCB 剪贴板](https://github.com/qt/qtbase/blob/v6.11.2/src/plugins/platforms/xcb/qxcbclipboard.cpp)、[Qt XCB MIME 匹配](https://github.com/qt/qtbase/blob/v6.11.2/src/plugins/platforms/xcb/qxcbmime.cpp)

### 3.2 `application/x-qt-image` 可以由 Qt 接收端合成

`QInternalMimeData` 的关键步骤：

1. `imageReadMimeFormats()` 取 `QImageReader::supportedImageFormats()`，转换成 `image/*`
   MIME，并优先排列 PNG。
2. `hasFormat("application/x-qt-image")`
   在原始平台格式没有该类型时，会继续检查是否存在可读取的图像 MIME。
3. `formats()` 在原始平台格式包含可读图像 MIME 时，主动追加 `application/x-qt-image`。
4. `retrieveData("application/x-qt-image", …)`
   若没直接读到 Qt 私有格式，会尝试读取这些图像 MIME；需要 QImage/QPixmap/QBitmap 时，把得到的字节经
   `QImage::fromData()`
   转成图像。[v6.11.2 源码](https://github.com/qt/qtbase/blob/v6.11.2/src/gui/kernel/qinternalmimedata.cpp)、[v6.8.0 对照](https://github.com/qt/qtbase/blob/v6.8.0/src/gui/kernel/qinternalmimedata.cpp)

因此，**不能仅在 `wl-paste` / `xclip TARGETS` 中找不到 `application/x-qt-image` 就断言 Qt 的
`hasImage()` 必为 false**。本次已映射 Qt 探针正好验证了源码描述的路径。

反过来，这也不保证闭源微信一定调用这些标准接口：它可以用自己的 MIME 白名单、缓存或编辑器粘贴处理。是否如此仍需微信进程内的观测，不能仅由 Qt 源码推断。

### 3.3 官方问题追踪检索的边界

`qt/qtbase` 官方 GitHub 仓库关闭了 Issues（API `has_issues=false`），其 GitHub
issue 搜索为空不能解释为“Qt 没有相关 bug”。本次能直接核对的是官方源码，未找到可直接证明 WeChat
4.1.1.4 此故障的 Qt 官方 issue。[Qt 官方仓库](https://github.com/qt/qtbase)

## 4. 相关上游问题：有哪些真实故障，为什么不能直接套用

下表是官方 xwayland-satellite 仓库中的原始报告；“Closed”只表示议题状态，不自动等同于任意场景都已修复。

| 原始来源                                                                                                                                            | 上游实际讨论的故障                                                                                                                                       | 与本次的关系                                                                                                     |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| [#82：Copy image failed with: unexpectedly requesting data](https://github.com/Supreeeme/xwayland-satellite/issues/82)，Closed，2024-12-21          | 从 X11 Discord 复制图片，X11→Wayland 没有图像；日志出现旧实现的 `TargetValue` 警告。维护者表示找到原因。                                                 | 是真实历史图片 bug，但方向相反、实现较旧；不是“所有 Wayland→微信 PNG 都失败”的证据。                             |
| [#245：wl-clip-persist causes the clipboard to lose copied content](https://github.com/Supreeeme/xwayland-satellite/issues/245)，Closed，2025-11-10 | 持久化工具交互、X11 TARGETS/PRIMARY 处理、空数据与复制丢失；讨论还提到某一 64 KiB 场景，不能和所有图片传输混同。后有报告者确认恢复。                     | 如果现场存在数据被清空/被重新接管才值得比对；当前同字节 PNG 可读，不能据此给工具或卫星定责。                     |
| [#91：Clipboard stops syncing … after running for a long time](https://github.com/Supreeeme/xwayland-satellite/issues/91)，Closed，2025-12-09       | 长时间运行失同步；中途混入多种应用与方向的报告，最终有用户反馈 Niri 特殊集成下恢复。                                                                     | 不能把某条“works for me”当本次微信修复，也不能把所有应用个案视为同一机制。                                       |
| [#485：Wayland selection exists but X11 CLIPBOARD owner is None](https://github.com/Supreeeme/xwayland-satellite/issues/485)，Open，2026-08-26 创建 | 报告环境 Niri 26.04 + satellite 0.8.2；Wayland 有 offer，而 X11 无 selection owner，多种 X11 应用都失败，重启可恢复；正文包含单独实例双向 PNG 成功记录。 | 和“Wayland 有 PNG”的表象接近，但本次 X11 确实能读到完整 PNG，**采样时不符合其核心特征**。不能据此断言复现 #485。 |
| [#431：ext-data-control 支持提议](https://github.com/Supreeeme/xwayland-satellite/pull/431)，Open                                                   | 主要动机之一是 X11 发起复制、却从未获得 Wayland 键盘焦点的混合协议客户端；原有 `last_kb_serial` 条件下无法向 compositor 注册源。                         | 不等价于目前强制 xcb 微信的纯 PNG 接收失败，不能不做区分就引入第二套桥接器。                                     |
| [#433：改用 Xwayland 内建桥接的提议](https://github.com/Supreeeme/xwayland-satellite/issues/433)，Open                                              | 讨论未来改用 Xwayland `-clipboard`；协作者在 2026-05-19 指出当时内建桥接不支持 INCR，而 satellite 支持。                                                 | 说明“换成 Xwayland 自带桥接”不是无代价、已证实的当前修复；该评论只说明当时状态，不代表所有后续 Xwayland 版本。   |

[v0.8.3 官方发布说明](https://github.com/Supreeeme/xwayland-satellite/releases/tag/v0.8.3)
列出的主要修复是 Steam 弹窗、装饰窗口的鼠标偏移及模糊，不包含“微信图片粘贴已修复”的声明。

#433 中另有工具作者提及 `xwayclip`，其[自身 README](https://github.com/so1ve/xwayclip)
目标是 QQ 等窗口协议与剪贴板协议混用的应用。这是该工具作者的一手设计说明，**不是腾讯/Qt 对微信 4.1.1.4 的兼容承诺**。本调查不把 QQ 的问题直接移植到已强制 xcb 的微信，也未安装运行该工具。

### 包装层旁证不等于微信行为证明

作为独立的打包实现旁证，Flathub 的[固定版本清单](https://github.com/flathub/com.tencent.WeChat/blob/80029fd3d55ede8022a124c586e2b7ca8e1a735c/com.tencent.WeChat.yaml#L8-L29)
同样使用 X11 socket 与 `QT_QPA_PLATFORM=xcb`，文件权限只显式添加 Downloads 只读、`.xwechat` /
`xwechat_files`
持久化；其[启动脚本](https://github.com/flathub/com.tencent.WeChat/blob/80029fd3d55ede8022a124c586e2b7ca8e1a735c/wechat.sh)
设置输入法环境、关闭 core
dump，然后执行微信，没有添加 PNG→URI 转换。这是打包项目源码，不是腾讯的兼容声明，也不证明本机 bubblewrap 权限等价。

同样，所核对的
[nixpkgs Linux 包装源码](https://github.com/NixOS/nixpkgs/blob/ebbfb683632eb0f965523520a621cf5f737d40c6/pkgs/by-name/we/wechat/linux.nix)
是解包 AppImage、替换 libtiff 依赖、`wrapAppImage`
及桌面图标安装，没有在该文件中实现剪贴板 MIME 修补。不能把“其他打包器也使用 xcb”解释为 raw
PNG 必然可粘贴，但也没有这里要求共享整个宿主机 `/tmp` 才能取图的证据。

## 5. 尚未验证的候选与最小判别依据

这部分是后续排查建议，不是本次已经执行的修复或微信验收。

| 候选                                      | 目前的依据和反证                                                                                    | 真正需要的判别证据                                                                                                                             |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 微信粘贴入口只请求文本、没有执行图像分支  | 故障时段日志以 TARGETS/UTF8_STRING 为主；标准 Qt 能识别图像。但尚未严格归属每个请求到微信进程。     | 把一次明确的微信粘贴动作、requestor X window 与微信进程对应起来，确认是快捷键、菜单入口、焦点还是 MIME 判定分支未取图。                        |
| 微信内部 Qt/插件/自定义代码与系统 Qt 不同 | 系统 Qt 探针不是微信进程，不能替它担保；但“系统 Qt 缺少 PNG/Qt 私有 MIME”已经不符合采样。           | 微信实际加载的 Qt/图像插件信息，以及微信是否调用标准 hasImage/imageData 或其他路径的直接证据。                                                 |
| 微信接受文件 URI，但不接受当前 raw PNG    | raw image 与 file URI 是不同 payload；当前仅提供 image/png，卫星不会自动生成文件。                  | 同一 PNG 的 raw-image 与实际可访问文件 URI 对照，并明确微信在哪个入口接受哪一种。成功 URI 只能证明存在可用文件路径，不能单独证明“只接受 URI”。 |
| 沙箱阻挡图片相关文件访问                  | home/tmp 被隔离使 URI/落盘路径值得调查；但 raw PNG 桥接不依赖原图宿主机路径，X11 PNG 字节也已可读。 | 先确定微信确实尝试打开某路径，再观察访问失败与粘贴动作关联；不能直接取消全部隔离来解释原始 PNG。                                               |
| 卫星的元目标实现边界导致客户端拒绝        | 0.8.3 的 TIMESTAMP/MULTIPLE 路径确有缺项；标准 Qt 探针已经不受影响，现场未见相应拒绝日志。          | 微信实际请求这些目标、收到失败并因此中止，或在只改变该条件的对照中恢复。                                                                       |
| 整体桥接失同步／大图 INCR 故障            | 上游确有类似类别 issue；但当前 X11/Wayland 小图同字节、Qt 成功解码，是反证。                        | 故障当时 X11 无 owner/无法取 PNG，或在尺寸增长到实际 INCR 路径时稳定失败；不能由现有小图结果推出。                                             |

**当前可交付判断：图片数据已跨过 Wayland→X11，标准 Qt
XCB 的图像识别/解码也已通过现场采样；微信自身为什么没有完成图像粘贴仍未确认。没有足够证据要求修改 Niri、解除沙箱隔离或替换剪贴板桥接器。**

## 6. 本轮已排除、仍未知，以及下一轮输入

- **在当前采样时刻已排除**：原始 PNG 没有到达 X11、当前 PNG 字节损坏、标准 Qt XCB 因缺少
  `application/x-qt-image` 而无法识别图片。这里不是宣称所有时间点和微信内部实现都已排除。
- **打包侧旁证**：并行调查核对上述 Flathub 清单对应 WeChat
  4.1.1.4，同样是 X11 与受限文件系统；未找到足以证明本机 raw
  PNG 粘贴失败根因的已确认上游报告。它不能替代微信实际粘贴行为验证。
- **仍未知**：该次微信粘贴动作是否真正向 X11 请求图像，以及客户端未完成粘贴的具体内部原因；文件 URI 和沙箱路径只在确实走文件路径时才成为相关变量。

用户随后确认：**截图后复制，粘贴完全无反应**。这将排查重点放在图片进入输入框之前，而非图片预览后的发送阶段；不能仅凭这一表现排除焦点、快捷键或客户端内部判断。

下一轮应对同一截图来源做受控粘贴，区分 Ctrl+V 与右键入口，避免把图像读取、文件访问和发送阶段混在一起。本轮不自动向任何会话发送内容，不重启微信、卫星或 Niri，也不先改配置来替代定位。

## 7. 补充调查：当前版本与 Niri 推荐路径

用户已明确故障操作是“截图后复制，粘贴完全无反应”。本次未在微信中完成受控图片粘贴对照，因此仍不宣称已经找到或修复客户端根因。

### 版本差异

| 项目                    | 调查结果                                                                                                                |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 当前运行的自定义包      | `bwraps.wechat` 固定 4.1.1.4 AppImage、隐藏 Wayland、强制 xcb                                                           |
| 本机 `<nixpkgs>` 包集合 | `nix eval --impure --raw --expr '(import <nixpkgs> {}).wechat.version'` 为 4.1.1.8；这不是仓库全部 flake 输出的版本审计 |
| 当前 nixpkgs master     | Linux 4.1.13.26，改为 DEB 包装，Wayland 会话默认原生 Wayland                                                            |
| 当前 Flathub            | 发布 API 显示 4.1.13.26；清单使用 Wayland 与 fallback-x11                                                               |
| 当前输入法              | Fcitx5 5.1.23，服务 active，当前引擎 rime，`XIM_SERVERS` 已注册 `@server=fcitx`                                         |

来源：[腾讯下载页](https://linux.weixin.qq.com/)、[腾讯 4.1.13 更新说明](https://weixin.qq.com/updates/linux/4113)、[nixpkgs 版本源](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/we/wechat/sources.json)、[Nix 包装重构 PR #560225](https://github.com/NixOS/nixpkgs/pull/560225)、[Flathub 发布 API](https://flathub.org/api/v2/appstream/com.tencent.WeChat)、[当前 Flathub 清单](https://github.com/flathub/com.tencent.WeChat/blob/master/com.tencent.WeChat.yaml)。

旧版本的“只支持 xcb”及为解决候选框问题隐藏 Wayland，是当前本机旧包的历史约束，不能外推为新版微信的永久限制。当前自定义包固定自己的源，升级普通
`pkgs.wechat` 不会自动更新它。

### 运行方式建议

优先评估**新版官方 Linux 微信 + 原生 Wayland**，保留旧版作为对照，而不是先换输入法或增加剪贴板桥接器。

- 保留现成沙箱、减少自维护包装：优先以新版 Flathub 做独立对照；它不是腾讯官方维护的分发仓库。
- 优先 Nix 声明式维护：采用包含上述重构的新版 nixpkgs 包；但裸 `pkgs.wechat`
  不等价于现有 home/tmp 隔离，不能在迁移时默默取消加固。
- 同一新版的 xcb 作为兼容回退；Wine 不是本次有证据支持的首选。
- 原生 Wayland 减少主窗口剪贴板与输入法的中间层，这是架构上的优势，不是本次故障已修复的证明。

[Flathub #98](https://github.com/flathub/com.tencent.WeChat/issues/98)
记录了早期原生 Wayland 下小程序等子进程的问题，以及 4.1.13.26 的恢复反馈；这不是 Niri 下外部截图粘贴的完整验收。[重新启用 Wayland 的提交](https://github.com/flathub/com.tencent.WeChat/commit/44c2cbb5bac96580c75e9675a8cf2ab5bb21b954)
与当前清单一致。Flatpak 的 `fallback-x11`
仅在 Wayland 不可用时提供 X11，不能理解成始终同时开放两种 socket，见[权限文档](https://docs.flatpak.org/en/latest/sandbox-permissions.html)。

### 输入法与粘贴应分别处理

Fcitx5 是输入法框架，Rime/小鹤双拼是引擎和方案；换成 Fcitx5 拼音不会自动改变微信的显示后端、候选框定位或 PNG 粘贴路径。目前没有证据将截图粘贴失败归因于 Rime。

新版 [nixpkgs 启动器](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/we/wechat/linux.nix)
在 Wayland 分支使用 `QT_QPA_PLATFORM=wayland`、`QT_IM_MODULE=text-input-unstable-v3`；新版
[Flathub 启动器](https://github.com/flathub/com.tencent.WeChat/blob/master/wechat.sh) 只在不存在
`WAYLAND_DISPLAY`
时注入 fcitx/ibus 模块。不能把旧版强制 XIM 的应用环境原样带入新版原生 Wayland，也不应为单个微信实验全局改动其他应用的输入法变量。

推荐保留 **Fcitx5 +
Rime 小鹤双拼**。Fcitx5 拼音/双拼主要是另一种引擎选择；迁移 IBus 或搜狗没有本机微信兼容性收益的直接证据，不应作为截图粘贴修复。Niri
26.04 的[初始化源码](https://github.com/niri-wm/niri/blob/v26.04/src/niri.rs)与[输入法 popup 处理](https://github.com/niri-wm/niri/blob/v26.04/src/handlers/mod.rs)已有 text-input/input-method 支持，不是合成器完全缺少输入法协议。

协议表述需注意：`QT_IM_MODULE=fcitx` 选择 Qt 模块，不等于强制 XIM；`XMODIFIERS=@im=fcitx` 和
`XIM_SERVERS` 注册才是 XIM 相关设置，注册成功不证明微信实际输入上下文走 XIM。Fcitx5 自带
[Fcitx4 兼容前端](https://github.com/fcitx/fcitx5/blob/master/src/frontend/fcitx4frontend/fcitx4frontend.cpp)，看到
`fcitx4` 也不意味着需要安装旧 Fcitx4。参见
[Fcitx 环境变量说明](https://fcitx-im.org/wiki/Input_method_related_environment_variables)。

微信自带的 Qt 与系统 Qt 应分开判断；Fcitx 维护者在
[4.1.1.8 相关讨论](https://github.com/fcitx/fcitx5/issues/1607)指出该应用使用静态链接 Qt。系统 Qt 识图成功不能替代微信验收。[Fcitx Wayland 指南](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland)也说明了闭源程序自带 Qt、text-input-v3 和候选窗定位的边界。新版微信优先采用其打包器明确支持的应用局部接入方式，不全局更换或清空输入法环境。

### 下一步验收边界

以下是建议，尚未实施：

1. 新版本使用独立数据目录，不能与旧版本同时读写同一份聊天数据。
2. 同一新版、同一打包先对比原生 Wayland 与 xcb，不同时变更多个变量。
3. 用同一截图来源检查 Ctrl+V 和右键粘贴，只观察图片预览，不发送。
4. 分别检查中文上屏、候选框位置、切换焦点、多屏缩放及小程序；截图粘贴与输入法分别验收。
5. 只有同版本后端对照后，再比较 Nix 与 Flathub 的库、环境和沙箱差异。

## 8. 新版按 Nix 接入的具体设计与试验

### 已验证：无需整体更新主依赖

根 flake 的 `nixpkgs` 实际映射到锁文件的 `nixpkgs_2`，提交为
`55bfb4d7437bd4e09ab7cba58a43bd68eb310044`，不是 WSL 依赖使用的同名节点。用这套依赖直接
`callPackage`
[固定上游提交 ea41ebe3e788f3f374e04885f4f60aca20efefed 的微信配方](https://github.com/NixOS/nixpkgs/tree/ea41ebe3e788f3f374e04885f4f60aca20efefed/pkgs/by-name/we/wechat)，求值与
`nix build --no-link` 均成功：

```text
version: 4.1.13.26
output: /nix/store/qmd261f5hvzy2yc1njn1izlvdis50x48-wechat-4.1.13.26
```

构建没有修改 flake、用户安装列表或当前系统 generation。无需额外覆盖 X11 库名、shell
wrapper 等参数；新配方的 `runtimeDependencies`、GL/EGL 动态依赖与 WMPF FFmpeg
ABI 修补必须保留，不能只替换旧 AppImage 的版本号和下载地址。

### 最小接入设计

推荐把固定上游的 Linux 配方局部回移到
`hardening/bwraps/`，使用现有包集合实例化，不引入第二套 nixpkgs 包集合。保留现有
`buildFHSEnv`/bubblewrap 外层，改为执行已完成依赖修补的新版
`bin/wechat`，不再使用 AppImage 解包机制。

保持公开入口 `pkgs.bwraps.wechat` 和 `wechat.desktop` 不变，因此 `misc.nix`、XDG
autostart 的消费者无需改名；正式切换后只保留一个默认微信入口，不增加长期双版本兼容别名。

外层保留当前 home/root 遮蔽、private tmp 和 namespace 设置，以及以下两项映射：

- `~/Documents/WeChat_Data/home` → 沙箱内原 `$HOME`。
- `~/Documents/WeChat_Data/xwechat_files` → 沙箱内相同的原绝对路径。

后者不能省掉：现有 `home/xwechat_files` 是指向绝对路径的链接，微信也可能保存了绝对路径。保持 `$HOME`
字符串不变，不能仅通过修改 `HOME` 环境变量代替实际文件系统遮蔽。

此次不是完整沙箱重设计。当前 FHS 包装器默认还自动映射 `/run` 等宿主目录，并透传
`/dev`；因此“保留隔离”主要指保持已有 home/tmp 和 namespace 边界，不能宣称已有严格 D-Bus 过滤或最小设备授权。

### 微信局部环境必须明确设置

仓库 `desktop-tools.nix` 已全局设置
`QT_QPA_PLATFORM=wayland`。上游新启动器仅在该变量为空时自动选择平台和输入法模块，因此只删除旧版 xcb 设置还不够：继承的变量会跳过上游自动分支。

微信外层应明确设置：

```text
QT_QPA_PLATFORM=wayland
QT_IM_MODULE=text-input-unstable-v3
NIXOS_OZONE_WL=1
```

保留
`WAYLAND_DISPLAY`；移除旧微信局部的 xcb/fcitx 强制值，不改变其他应用的全局设置。`NIXOS_OZONE_WL`
用于触发上游 WeChatAppEx 子进程的 Wayland 分支，不是微信截图粘贴修复开关。

NVIDIA 运行时还需检查宿主 `/run/opengl-driver`、`/dev/nvidia*` 与 EGL 平台配置。现有 Nixpak
GUI 模块已只读映射 `/etc/egl`、`/etc/static/egl`，而现有 FHS 包装默认的 `/etc`
列表不等价；新外层应显式处理这些只读配置及链接目标并验收，不能把包内 Mesa/libglvnd 当成主机 NVIDIA 驱动替代品。

### 已执行的启动试验与限制

使用临时家目录、独立 D-Bus、bubblewrap 文件系统隔离，以及上述主窗口 Wayland/text-input-v3 环境，启动构建出的新版约六秒。Niri 返回新版
`wechat`
主窗口，PID 为实际微信进程，而旧微信窗口的 PID 仍为 XWayland 桥接进程；新版当时仍在运行，随后主动终止试验进程并删除临时数据。未登录、未读取或升级原聊天数据。

这证明本机能够启动新版原生 Wayland 顶层窗口，不是最终 FHS 包装器的验收，也不证明登录、候选框、截图粘贴和小程序通过。独立 D-Bus 的人工测试环境出现文档 portal
FUSE 与 secrets 服务错误，因此文件对话框、portal 和共享屏幕不计入通过项。正式接入应使用现有桌面会话服务，不照搬试验用的第二套 portal 会话。

### 数据与回滚

调查时现有 home 与 files 目录占用约 404 MiB、808
MiB。正式切换前先正常退出旧微信，再备份两者；复制活跃数据库不能视为一致备份。首次新版本访问可能修改数据库，目前没有证据保证降级兼容。

测试副本时必须同时映射副本 home 和副本 files，且在沙箱内仍保持原路径；只复制 home 会让其中的绝对链接重新指向在线 files 数据，破坏隔离测试。

回滚应恢复旧包和升级前的一致数据备份，而非让旧二进制直接打开新版修改过的数据。新旧版本不得同时写同一份 home/files。登录后的截图粘贴、Rime 上屏/候选框定位、文件收发、小程序与视频功能分别验收后，才切换默认入口。

## 9. 最终接入选择

用户明确要求不使用沙箱、不隔离数据路径。最终实现改为 `overlays/wechat/` 局部覆盖
`pkgs.wechat`，安装与自启动均直接使用新版 DEB 包；移除旧 `hardening/bwraps`
配方、主机导入与旧包入口。不使用 FHS/bubblewrap，不改写 HOME/XDG，也不创建 `WeChat_Data`
映射。第 8 节保留的外层沙箱设计不再实施。

版本固定 `4.1.13.26`，微信局部显式使用 Wayland、text-input-v3 与 WeChatAppEx
Wayland 参数；Fcitx5/Rime 保持不变。旧 `WeChat_Data` 不迁移、不删除，普通 `~/xwechat_files`
已存在，本次不覆盖或合并任何数据。登录与历史数据迁移属于独立操作，不能把新版启动成功视为聊天记录迁移成功。
