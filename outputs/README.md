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
├── aarch64-linux/
│   ├── default.nix
│   ├── src/
│   │   └── empty.nix
│   └── tests/
└── x86_64-linux/
    ├── default.nix
    ├── src/
    │   ├── olympians-apollo.nix
    │   ├── olympians-athena.nix
    │   ├── olympians-generic.nix
    │   └── olympians-hermes.nix
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
| `darwinConfigurations` | `artemis`                     | `outputs/aarch64-darwin/src/artemis.nix`        |
| `homeConfigurations`   | `hermes`                      | `outputs/x86_64-linux/src/olympians-hermes.nix` |
| `packages.<system>`    | 主机 ISO 等包输出             | 各平台 `src/*.nix` 中的 `packages`              |
| `checks.<system>`      | eval tests、pre-commit check  | `outputs/default.nix`                           |
| `devShells.<system>`   | 默认开发 shell                | `outputs/default.nix`                           |

新增主机时优先复制相近主机文件，再改 `name`、模块列表和必要的主机差异。

## 测试

当前主要使用 eval tests。它不会构建完整机器，但能快速确认关键属性是否符合预期。

运行所有 eval tests:

```bash
nix eval .#evalTests --show-trace --print-build-logs --verbose
```

NixOS VM tests 暂未作为主路径使用。原因是完整主机依赖私有 agenix
secrets 和主机专属 key，直接跑整机测试成本较高。

## 参考

- [haumea](https://github.com/nix-community/haumea)
- [NixOS integration tests](https://nixcademy.com/2023/10/24/nixos-integration-tests/)
- [NixOS Tests - NixOS Manual](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
