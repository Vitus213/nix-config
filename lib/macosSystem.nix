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
              # herdr 0.7.1 的 zig 构建（vendored libghostty-vt）通过
              # `xcode-select --print-path` + `xcrun --sdk macosx --show-sdk-path`
              # 探测 macOS SDK；而 0.7.1 的包定义未引入 cctools/xcbuild，
              # 构建环境没有这两个命令。补齐 cctools/xcbuild（shim）与
              # apple-sdk（提供 DEVELOPER_DIR），并显式导出兜底。
              # 注意：必须是 apple-sdk_15——zig 0.15.2 的 build 模式链接
              # build_runner 时与 SDK 26 的 libSystem.tbd 不兼容
              # （undefined symbol），SDK 15 实测正常。
              # TODO: nixpkgs 升级到含 herdr 0.8.2+（已补齐依赖）后可移除。
              (_: super: {
                herdr = super.herdr.overrideAttrs (oldAttrs: {
                  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
                    super.cctools
                    super.xcbuild
                    super.apple-sdk_15
                  ];
                  # apple-sdk 的 setup hook 在部分构建环境下不生效
                  # （__structuredAttrs），这里显式导出 DEVELOPER_DIR 与
                  # SDKROOT 兜底：xcode-select/xcrun 依赖前者定位 SDK，
                  # zig 链接器依赖后者定位 libSystem.tbd。
                  preConfigure = (oldAttrs.preConfigure or "") + ''
                    export DEVELOPER_DIR=${super.apple-sdk_15}
                    export SDKROOT=${super.apple-sdk_15}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
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
