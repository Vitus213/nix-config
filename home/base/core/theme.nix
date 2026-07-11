{ catppuccin, pkgs, ... }:

let
  catppuccinPackages = catppuccin.packages.${pkgs.stdenv.hostPlatform.system};

  catppuccinVscode = pkgs.callPackage (
    {
      lib,
      vscode-utils,
      fetchPnpmDeps,
      pnpmConfigHook,
      nodejs-slim_24,
      pnpm_10,
      catppuccinOptions ? { },
    }:
    let
      nodejs-slim = nodejs-slim_24;
      pnpm = pnpm_10.override { inherit nodejs-slim; };
    in
    vscode-utils.buildVscodeExtension (finalAttrs: {
      pname = "catppuccin-vscode";
      version = "3.19.0";

      src = catppuccinPackages.fetchCatppuccinPort {
        port = "vscode";
        tag = "@catppuccin/vscode-v${finalAttrs.version}";
        hash = "sha256-HUXRGK10A3YIU6ksTfzOzQvM5J699lJikndlYUgrkRA=";
      };

      vscodeExtPublisher = "catppuccin";
      vscodeExtName = "vscode";
      vscodeExtUniqueId = "catppuccin.vscode";

      sourceRoot = null;

      pnpmWorkspaces = [ "catppuccin-vsc" ];
      pnpmDeps = fetchPnpmDeps {
        inherit (finalAttrs)
          pname
          version
          src
          pnpmWorkspaces
          ;
        inherit pnpm;
        fetcherVersion = 3;
        hash = "sha256-DE0mHkBlV0RkrEmtIXnzKaiXOK8vgcCx3z7b49zzBhc=";
      };

      nativeBuildInputs = [
        nodejs-slim
        pnpm
        pnpmConfigHook
      ];

      __structuredAttrs = true;
      strictDeps = true;

      env = lib.optionalAttrs (catppuccinOptions != { }) {
        CATPPUCCIN_OPTIONS = builtins.toJSON catppuccinOptions;
      };

      buildPhase = ''
        runHook preBuild

        pnpm --filter catppuccin-vsc core:build --no-regenerate

        cd packages/catppuccin-vsc
        node dist/hooks/generateThemes.cjs
        touch ./themes/.flag

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/$installPrefix"
        cp -rL ../../LICENSE ../../README.md package.json icon.png dist/ themes/ "$out/$installPrefix/"

        runHook postInstall
      '';
    })
  ) { };
in
{
  # https://github.com/catppuccin/nix
  imports = [
    catppuccin.homeModules.catppuccin
  ];

  catppuccin = {
    # Keep current default enrollment explicit for catppuccin/nix 27.05 semantics.
    enable = true;
    autoEnable = true;
    # one of "latte", "frappe", "macchiato", "mocha"
    flavor = "mocha";
    # one of "blue", "flamingo", "green", "lavender", "maroon", "mauve", "peach", "pink", "red", "rosewater", "sapphire", "sky", "teal", "yellow"
    accent = "pink";

    sources.vscode = catppuccinVscode;
  };
}
