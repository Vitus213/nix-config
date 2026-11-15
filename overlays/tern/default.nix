_: final: prev: {
  # nixpkgs.tern 是数据库迁移工具，Stencil Tern 单独命名。
  tern-stencil = final.callPackage (
    if prev.stdenv.hostPlatform.isDarwin then ./darwin.nix else ./linux.nix
  ) { };
}
