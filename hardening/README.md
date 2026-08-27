# Linux 加固

> 仍在整理中。

这个目录存放系统级和应用级沙箱/加固配置。

## 目标

- 系统级: 降低关键文件被非预期程序读取的风险，例如浏览器 cookie、SSH key
- 应用级: 限制闭源或不可信应用访问文件、网络和硬件设备

加固和沙箱不能让运行不可信代码变得绝对安全。真正不可信的代码应放到 VM 和隔离网络中运行。

## 当前结构

```text
hardening/
├── apparmor/   # AppArmor 配置
├── bwraps/     # 直接使用 bubblewrap 的沙箱
├── nixpaks/    # 基于 nixpak 的应用沙箱
└── profiles/   # 系统加固 profile
```

## 当前状态

| 组件              | 状态   | 说明            |
| ----------------- | ------ | --------------- |
| AppArmor          | 整理中 | 基础结构已存在  |
| Nixpak QQ         | 使用中 | QQ 沙箱         |
| Bubblewrap WeChat | 使用中 | WeChat 专用沙箱 |
| 系统 profile      | 整理中 | 系统级加固配置  |

NixOS 桌面上的微信和 QQ 使用方式见 [Linux 微信与 QQ](../documents/linux-im-apps.md)。

## 参考方向

- Kernel hardening:
  <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/kernel/hardened/config.nix>
- NixOS hardened profile:
  <https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/profiles/hardened.nix>
- AppArmor: <https://gitlab.com/apparmor/apparmor/-/wikis/Documentation>
- AppArmor profile 集合: <https://github.com/roddhjav/apparmor.d>
- Bubblewrap: <https://github.com/containers/bubblewrap>
- Nixpak: <https://github.com/nixpak/nixpak>
- Firejail: <https://wiki.nixos.org/wiki/Firejail>
- Systemd hardening: <https://wiki.nixos.org/wiki/Systemd/Hardening>

## 参考文章

- [Harden your NixOS workstation](https://dataswamp.org/~solene/2022-01-13-nixos-hardened.html)
- [Linux Insecurities](https://madaidans-insecurities.github.io/linux.html)
- [Sandboxing all programs by default](https://discourse.nixos.org/t/sandboxing-all-programs-by-default/7792)
- [Paranoid NixOS Setup](https://xeiaso.net/blog/paranoid-nixos-2021-07-18/)
- [nix-mineral](https://github.com/cynicsketch/nix-mineral)
