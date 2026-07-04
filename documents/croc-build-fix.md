# Croc build 修复

## 当前行为

`modules/base/packages.nix` 仍安装 `pkgs.croc`，但仓库通过 `overlays/croc/default.nix` 临时覆盖
`pkgs.croc.src`。

当前覆盖内容:

- `version`: 仍跟随主 `nixpkgs` 的 `10.4.5`
- `rev`: 固定到当前 `v10.4.5` tag 指向的 commit `57e5fd7cef0466e3dbe086e18d00fc9e40e4dffa`
- `hash`: `sha256-u262LwHUL6+rPE7nzIda7W5dAXaikQ/cKwtUEIbcbH0=`

## 背景

`apollo` toplevel build 在 `croc-10.4.5-go-modules` 处失败，错误为 fixed-output derivation hash
mismatch:

- nixpkgs 指定：`sha256-EbOjLR9xQMY2D+roK/Fv1so5FZwZ2RmNetLxq0WIw2g=`
- 当前下载：`sha256-u262LwHUL6+rPE7nzIda7W5dAXaikQ/cKwtUEIbcbH0=`

`nix-prefetch-url --unpack` 对当前 `v10.4.5` tag 和 commit
`57e5fd7cef0466e3dbe086e18d00fc9e40e4dffa` 的结果一致。临时 overlay 只修正 `src` 后， `pkgs.croc`
可以完成 Go module vendor、编译和 version check。

## 回滚

当主 `nixpkgs` 更新到包含 croc 修复的 revision 后，删除 `overlays/croc/` 即可。删除后需要重新执行:

```bash
nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace
```

## 验证

```bash
nix build .#nixosConfigurations.apollo.pkgs.croc --no-link --print-build-logs
nix build .#nixosConfigurations.apollo.config.system.build.toplevel --no-link --show-trace --print-build-logs
```
