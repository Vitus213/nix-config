{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "flclash";
  version = "0.9.4";

  src = fetchurl {
    url = "https://github.com/chen08209/FlClash/releases/download/v${finalAttrs.version}/FlClash-${finalAttrs.version}-macos-arm64.dmg";
    hash = "sha256-2weE5+Wmn8k9qFrM9NjYCBLn4BTyCCYJ2jlbphJBlcU=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = "FlClash.app";
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  # Keep the upstream app bundle and its embedded helper signatures intact.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications/FlClash.app"
    cp -R . "$out/Applications/FlClash.app"
    runHook postInstall
  '';

  meta = {
    description = "Cross-platform proxy client based on Mihomo";
    homepage = "https://github.com/chen08209/FlClash";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
