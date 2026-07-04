# Niri 显示缩放

本文记录 NixOS 桌面在 Niri 下的显示器缩放配置。

## 当前配置

`apollo` 主机当前使用 Niri `26.04`，系统求值版本为 NixOS `26.11.20260702.6517942`。

`DP-1` 是主显示器，当前识别为 `Shenzhen KTC Technology Group H27T22S-3 Pro`：

- 分辨率：`2560x1440`
- 刷新率：`200.000 Hz`
- 物理尺寸：`600x330 mm`
- Niri 缩放：`1.24`

这个缩放对应约 124%，用于接近同一块 2K 屏幕在 Windows 上使用的 124% 缩放观感。

## 配置入口

主配置入口是：

- `hosts/olympians-apollo/niri-hardware.kdl`

Home Manager 会把该文件链接到：

- `~/.config/niri/niri-hardware.kdl`

`home/linux/gui/niri/conf/config.kdl` 通过 `include "./niri-hardware.kdl"` 载入主机级输出配置。

## 调整方式

修改 `hosts/olympians-apollo/niri-hardware.kdl` 中对应输出的 `scale`：

```kdl
output "DP-1" {
    scale 1.24
    mode "2560x1440@200.000"
    position x=0 y=0
}
```

`scale 1` 表示 100%，`scale 1.24` 表示约 124%，`scale 1.25` 表示 125%。

Niri 支持配置热重载，保存文件后通常会自动应用。可以用下面的命令查看实际状态：

```bash
niri msg outputs
```

也可以临时测试某个缩放值，不写入配置文件：

```bash
niri msg output DP-1 scale 1.25
```

临时修改只用于试手感；确定后仍应写回 `hosts/olympians-apollo/niri-hardware.kdl`。

## 验证

语法校验：

```bash
niri validate
```

运行状态检查：

```bash
niri msg outputs
```

期望 `DP-1` 显示约 `Scale: 1.24`。Niri 可能会把配置里的 `scale 1.24` 换算成接近值显示，例如
`1.2416666666666667`。

## 回滚

如果 124% 观感不合适，把 `hosts/olympians-apollo/niri-hardware.kdl` 中的 `scale 1.24` 改回
`scale 1`，保存后等待 Niri 热重载，再执行 `niri msg outputs` 确认。
