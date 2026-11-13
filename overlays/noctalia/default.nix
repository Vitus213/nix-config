{ noctalia, ... }:
_: prev:
let
  system = prev.stdenv.hostPlatform.system;
  supported = [
    "x86_64-linux"
    "aarch64-linux"
  ];
in
prev.lib.optionalAttrs (builtins.elem system supported) {
  noctalia = noctalia.packages.${system}.default.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ./dedicated-pam.patch
      ./workspace-states.patch
    ];
  });
}
