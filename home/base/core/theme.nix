{
  catppuccin,
  pkgs,
  lib,
  ...
}:

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

  # GTK 窗口主题：此前 gtk.theme 为空，Nautilus 等 GTK 应用跑 libadwaita 默认灰。
  # 与仓库 Catppuccin Mocha/Pink 身份对齐；仅 Linux（darwin 无 GTK 桌面需求）。
  # gtk4.theme 显式置 null：新版 home-manager 要求对 gtk.theme → gtk4 的隐式传播
  # 做显式决策，否则每次求值打弃用警告。
  gtk = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
    enable = true;
    theme = {
      package = pkgs.catppuccin-gtk.override {
        variant = "mocha";
        accents = [ "pink" ];
        size = "standard";
        tweaks = [ "rimless" ];
      };
      name = "catppuccin-mocha-pink-standard+rimless";
    };
    gtk4.theme = null;
  };
}
