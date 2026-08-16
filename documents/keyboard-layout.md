# Esc 与 Caps Lock 原生键位

本文记录 NixOS 和 macOS 当前的 Esc、Caps Lock 键位行为、配置入口、部署与回滚方式。

## 当前行为

仓库不再配置 Esc 与 Caps Lock 的系统级重映射：

- 按下 `Esc` 发送 Escape。
- 按下 `Caps Lock` 切换系统大写锁定状态。
- `Caps Lock` 不再具有点按 Escape、长按 Control 的复合行为。

Linux 桌面未启用 `services.keyd`。macOS 未启用 nix-darwin 的
`system.keyboard.enableKeyMapping`，`system.keyboard.userKeyMapping` 为空。

Fcitx5/Rime 仍将 `Caps_Lock` 设为 `noop`。这只阻止 Rime 使用 Caps Lock 切换中西文状态，不会把 Caps
Lock 映射成其他按键；大小写锁定仍由系统处理。

## 配置入口

- Linux 外设配置：`modules/nixos/desktop/peripherals.nix`
- macOS 系统配置：`modules/darwin/system.nix`
- Rime 输入法补丁：`home/linux/gui/base/fcitx5/default.custom.yaml`

## 部署与验证

NixOS 需要在目标主机完成正常的系统重建后生效；重建会停止并移除之前由配置启用的
`keyd.service`。macOS 需要执行正常的 nix-darwin 重建，激活脚本会将 `hidutil` 的 `UserKeyMapping`
设置为空。

部署后直接测试两个实体键：`Esc` 应执行应用的退出或取消操作，`Caps Lock`
指示灯和字母大小写应随按键切换。Linux 还可检查
`systemctl status keyd.service`，该服务应不存在或未启用；macOS 可执行
`hidutil property --get UserKeyMapping`，结果应为空。

## 回滚

如需恢复旧行为：Linux 在 `modules/nixos/desktop/peripherals.nix` 中重新启用 `services.keyd`，将
`capslock` 映射为 `overload(control, esc)` 并将 `esc` 映射为 `capslock`；macOS 在
`modules/darwin/system.nix` 中重新启用 `system.keyboard` 的 Caps
Lock 到 Escape 映射，并添加 Escape 到 Caps Lock 的 `userKeyMapping`。修改后重新构建对应系统。
