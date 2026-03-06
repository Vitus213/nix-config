{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
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
