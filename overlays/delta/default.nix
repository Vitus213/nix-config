{ delta, ... }:
_: prev:
let
  system = prev.stdenv.hostPlatform.system;
  supported = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
  ];

  darwin = prev.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "delta-zed";
    version = "0.23.0";
    src = prev.fetchurl {
      url = "https://releases.delta.dev/releases/stable/${finalAttrs.version}/macos/aarch64/Delta.app.zip";
      hash = "sha256-2/ri+IEXATFcMghTRjWbVRHA4zdDvyoxhzA1r+GSu30=";
    };
    nativeBuildInputs = [
      prev.unzip
      prev.makeWrapper
    ];
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    # Preserve the signature of the upstream app bundle.
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications" "$out/bin"
      cp -R Delta.app "$out/Applications/Delta.app"
      makeWrapper "$out/Applications/Delta.app/Contents/MacOS/delta" "$out/bin/delta-zed"
      makeWrapper "$out/Applications/Delta.app/Contents/MacOS/delta-app" "$out/bin/delta-app"
      runHook postInstall
    '';
    meta = {
      description = "Zed's multiplayer environment for coding with agents";
      homepage = "https://delta.dev";
      license = prev.lib.licenses.unfree;
      mainProgram = "delta-zed";
      platforms = [ "aarch64-darwin" ];
    };
  });

  # 上游 delta-nix 同时提供 bin/delta（CLI）与 bin/delta-app（GUI）。
  # bin/delta 与 nixpkgs 的 git-delta 冲突，这里把 CLI 改名为 delta-zed。
  upstream = delta.packages.${system}.delta;

  delta-zed =
    prev.runCommand "delta-zed-${upstream.version}"
      {
        nativeBuildInputs = [ prev.makeWrapper ];
        meta = upstream.meta // {
          mainProgram = "delta-app";
        };
      }
      ''
        mkdir -p "$out/bin" "$out/share/applications"
        ln -s ${upstream}/share/icons "$out/share/icons"

        makeWrapper ${upstream}/bin/delta "$out/bin/delta-zed"
        makeWrapper ${upstream}/bin/delta-app "$out/bin/delta-app"

        for desktop in ${upstream}/share/applications/*.desktop; do
          output="$out/share/applications/$(basename "$desktop")"
          sed "s|^Exec=.*|Exec=$out/bin/delta-zed open %U|" "$desktop" > "$output"
        done
      '';
in
{
  delta-zed =
    if system == "aarch64-darwin" then
      darwin
    else if builtins.elem system supported then
      delta-zed
    else
      throw "delta-zed is only packaged for ${builtins.concatStringsSep ", " supported}";
}
