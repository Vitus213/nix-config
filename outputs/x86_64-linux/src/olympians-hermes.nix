{
  # NOTE: haumea 只把签名里显式命名的参数从 args 中传入；保留完整参数列表，
  # 与其余 src 文件一致。
  inputs,
  lib,
  mylib,
  myvars,
  system,
  genSpecialArgs,
  ...
}:

let
  inherit (inputs) nixpkgs home-manager;
  name = "hermes";
  base-modules = {
    home-modules =
      (map mylib.relativeToRoot [
        "secrets/home.nix"
        "home/linux/tui.nix"
        "hosts/olympians-${name}/home.nix"
      ])
      ++ [
        {
          modules.secrets.home.enable = true;
          programs.home-manager.enable = true;
        }
      ];
  };
in
{
  homeConfigurations.${name} = home-manager.lib.homeManagerConfiguration {
    # Keep standalone HM package set aligned with the x86_64-linux platform.
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    extraSpecialArgs = genSpecialArgs system;
    modules = base-modules.home-modules;
  };
}
