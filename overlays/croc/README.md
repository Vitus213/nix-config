# Croc overlay

这个 overlay 临时修正 `pkgs.croc` 的源码固定值。

当前主 `nixpkgs` 中 `croc 10.4.5` 仍使用 `v10.4.5` tag，但实际下载到的 GitHub archive hash 已变为
`sha256-u262LwHUL6+rPE7nzIda7W5dAXaikQ/cKwtUEIbcbH0=`，导致 fixed-output derivation 在 `apollo`
toplevel build 时失败。

为避免继续依赖可变 tag，本 overlay 将 `src.rev` 固定到当前 `v10.4.5` tag 指向的 commit
`57e5fd7cef0466e3dbe086e18d00fc9e40e4dffa`，并同步更新源码 hash。`vendorHash`
不需要修改，临时 overlay 构建验证已通过。

当上游 `nixpkgs` 修复 `pkgs.croc` 或仓库更新到包含修复的 `nixpkgs` rev 后，可以删除本目录。
