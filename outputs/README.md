# Flake 输出

这个目录定义仓库对外暴露的 flake outputs，包括 NixOS、nix-darwin、home-manager、包和测试。

## 为什么拆得这么细

机器数量少时，把所有 output 写在一个文件里也能工作。机器数量增加后，如果继续集中维护，主机差异、平台差异和测试入口会很快混在一起。

当前结构按平台拆分，再在 `src/` 里为每台主机单独建文件。这样新增或删除主机时，影响范围更小。

## 目录结构

```text
outputs/
├── default.nix
├── aarch64-darwin/
│   ├── default.nix
│   ├── src/
│   │   └── artemis.nix
│   └── tests/
└── x86_64-linux/
    ├── default.nix
    ├── src/
    │   ├── olympians-apollo.nix
    │   ├── olympians-athena.nix
    │   ├── olympians-generic.nix
    │   ├── olympians-hermes.nix
    │   └── hestia.nix
    └── tests/
```

## 主机 output

每个 `src/<name>.nix` 通常负责:

- 定义主机名
- 选择系统架构
- 组合 NixOS / Darwin 模块
- 组合 home-manager 模块
- 暴露相关 package 或测试入口

当前主要 output:

| output 类型            | 名称                          | 来源文件                                        |
| ---------------------- | ----------------------------- | ----------------------------------------------- |
| `nixosConfigurations`  | `apollo`、`athena`、`generic` | `outputs/x86_64-linux/src/olympians-*.nix`      |
| `nixosConfigurations`  | `hestia`（NixOS-WSL）         | `outputs/x86_64-linux/src/hestia.nix`           |
| `darwinConfigurations` | `artemis`                     | `outputs/aarch64-darwin/src/artemis.nix`        |
| `homeConfigurations`   | `hermes`                      | `outputs/x86_64-linux/src/olympians-hermes.nix` |
| `packages.<system>`    | 主机 ISO 等包输出             | 各平台 `src/*.nix` 中的 `packages`              |
| `checks.<system>`      | eval tests、pre-commit check  | `outputs/default.nix`                           |
| `devShells.<system>`   | 默认开发 shell                | `outputs/default.nix`                           |

新增主机时优先复制相近主机文件，再改 `name`、模块列表和必要的主机差异。

Apollo 和 Generic 的 ISO 包直接使用 NixOS 原生 `config.system.build.images.iso`，不再注入
`nixos-generators`
的所有格式模块。共享参数只透传 inputs、mylib 和 myvars，媒体包使用主机同一包集。两份主机输出在
`image.modules.iso.isoImage` 显式设置 `makeEfiBootable = true` 与
`makeUsbBootable = true`，保留原生成器的 UEFI 和 USB 混合引导能力；这些参数只影响 ISO 变体。

## 测试

当前主要使用 eval tests。它不会构建完整机器，但能快速确认关键属性是否符合预期。

保留的断言覆盖内核主次版本必须为 `6.18`、固定桌面集合 Apollo/Athena/Generic 的专用 PAM 栈，以及 Home
Manager 的 SSH
secret 主机边界。PAM 服务缺失会直接失败，不通过过滤配置缩小被测集合。仅比较主机名、固定家目录或重复接线属性的测试已删除。haumea 导入器仍保留各平台测试输出结构。

运行所有 eval tests:

```bash
just test
# 或显式把 false 转为失败退出状态：
nix eval .#evalTests --apply 'passed: assert passed; passed' --show-trace
```

NixOS VM tests 暂未作为主路径使用。原因是完整主机依赖私有 agenix
secrets 和主机专属 key，直接跑整机测试成本较高。

纯求值不能替代 Home Manager activation
smoke、Linux 采集/PAM 构建或 Darwin 平台求值；特别是 activation 才触发的 PATH 冲突和平台包可用性，需单独验收。测试不执行系统切换。

## 参考

- [haumea](https://github.com/nix-community/haumea)
- [NixOS integration tests](https://nixcademy.com/2023/10/24/nixos-integration-tests/)
- [NixOS Tests - NixOS Manual](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
