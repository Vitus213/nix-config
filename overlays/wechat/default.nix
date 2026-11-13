_: _: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  wechat = prev.callPackage ./package.nix { };
}
