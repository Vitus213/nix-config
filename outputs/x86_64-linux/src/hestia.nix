{
  # NOTE: haumea 只把签名里显式命名的参数从 args 中传入，@args 再整体透传给
  # mylib.nixosSystem。因此这些参数即使本文件没有直接使用，也必须保留在签名里。
  inputs,
  lib,
  mylib,
  myvars,
  system,
  genSpecialArgs,
  ...
}@args:
let
  name = "hestia";
  base-modules = {
    nixos-modules = [
      (mylib.relativeToRoot "hosts/${name}")
    ];
    home-modules = (
      map mylib.relativeToRoot [
        # 终端链：与 hermes（Ubuntu）保持一致，不导入 gui.nix
        "home/linux/tui.nix"
        "hosts/${name}/home.nix"
      ]
    );
  };
in
{
  nixosConfigurations.${name} = mylib.nixosSystem (base-modules // args);

  packages.${name} = inputs.self.nixosConfigurations.${name}.config.system.build.toplevel;
}