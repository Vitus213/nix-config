{
  # NOTE: haumea 只把签名里显式命名的参数从 args 中传入，`@args` 再整体透传给
  # mylib.macosSystem（其内部使用 inputs / lib / myvars / system / genSpecialArgs）。
  # 因此这些参数即使本文件没有直接使用，也必须保留在签名里。
  inputs,
  lib,
  mylib,
  myvars,
  system,
  genSpecialArgs,
  ...
}@args:
let
  name = "artemis";

  modules = {
    darwin-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/darwin.nix"
        "modules/darwin"
        # host specific
        "hosts/darwin-${name}"
      ])
      ++ [
        {
          modules.desktop.fonts.enable = true;
        }
      ];
    home-modules = map mylib.relativeToRoot [
      "hosts/darwin-${name}/home.nix"
      "home/darwin"
    ];
  };

  systemArgs = modules // args;
in
{
  # macOS's configuration
  darwinConfigurations.${name} = mylib.macosSystem systemArgs;
}
