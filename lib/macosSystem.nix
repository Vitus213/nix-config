{
  lib,
  inputs,
  darwin-modules,
  home-modules ? [ ],
  myvars,
  system,
  genSpecialArgs,
  specialArgs ? (genSpecialArgs system),
  ...
}:
let
  inherit (inputs) nixpkgs-darwin home-manager nix-darwin;

  brokenPackages = [
    "terraform"
    "terraformer"
    "packer"
    "git-trim"
    "conda"
    "mitmproxy"
    "insomnia"
    "wireshark"
    "jsonnet"
    "zls"
    "verible"
    "gdb"
    "ncdu"
    "racket-minimal"
  ];
in
nix-darwin.lib.darwinSystem {
  inherit system specialArgs;
  modules =
    darwin-modules
    ++ [
      (
        { lib, ... }:
        {
          nixpkgs.pkgs = import nixpkgs-darwin {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              # Remove packages that are not well supported for Darwin
              (
                _: super:
                let
                  removeUnwantedPackages =
                    pname: lib.warn "the ${pname} has been removed on the darwin platform" super.emptyDirectory;
                in
                lib.genAttrs brokenPackages removeUnwantedPackages
              )
              # Fix direnv build failure: -linkmode=external requires cgo
              (_: super: {
                direnv = super.direnv.overrideAttrs (oldAttrs: {
                  buildPhase = ''
                    export CGO_ENABLED=1
                    ${oldAttrs.buildPhase or "make"}
                  '';
                });
              })
            ];
          };
        }
      )
    ]
    ++ (lib.optionals ((lib.lists.length home-modules) > 0) [
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "home-manager.backup";

        home-manager.extraSpecialArgs = specialArgs;
        home-manager.users."${myvars.username}".imports = home-modules;
      }
    ]);
}
