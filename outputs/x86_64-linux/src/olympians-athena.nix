{
  # NOTE: haumea 只把签名里显式命名的参数从 args 中传入，`@args` 再整体透传给
  # mylib.nixosSystem（其内部使用 system / genSpecialArgs / inputs / myvars 等）。
  # 因此这些参数即使本文件没有直接使用，也必须保留在签名里。
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  ...
}@args:
let
  # 雅典娜, Athena：开发机 + 家庭服务，桌面与 apollo 相同（niri），平时远程使用
  name = "athena";
  base-modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/desktop.nix"
        # host specific
        "hosts/olympians-${name}"
        # home/linux/gui 引用的 pkgs.nixpaks / pkgs.bwraps 由这两项提供
        "hardening/nixpaks"
        "hardening/bwraps"
      ])
      ++ [
        {
          modules.desktop.fonts.enable = true;
          modules.desktop.wayland.enable = true;
          modules.secrets.desktop.enable = true;
        }
      ];
    home-modules = map mylib.relativeToRoot [
      # common
      "home/linux/gui.nix"
      # host specific
      "hosts/olympians-${name}/home.nix"
    ];
  };

  modules-niri = {
    nixos-modules = [
      { programs.niri.enable = true; }
    ]
    ++ base-modules.nixos-modules;
    home-modules = [
      { modules.desktop.niri.enable = true; }
    ]
    ++ base-modules.home-modules;
  };
in
{
  nixosConfigurations.${name} = mylib.nixosSystem (modules-niri // args);

  packages.${name} = inputs.self.nixosConfigurations.${name}.config.system.build.toplevel;
}
