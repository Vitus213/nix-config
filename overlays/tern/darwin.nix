{
  lib,
  stdenvNoCC,
  requireFile,
  undmg,
  makeWrapper,
  bashInteractive,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tern-stencil";
  version = "0.9.21";

  src = requireFile {
    name = "Tern-${finalAttrs.version}-macos-arm64.dmg";
    url = "https://build.stencil.so/tern";
    sha256 = "9ecc90f95857af7c3f58bf2724ade7e9737c14791bc6fecee39542539df4f594";
  };

  nativeBuildInputs = [
    undmg
    makeWrapper
  ];
  sourceRoot = "Tern.app";
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  # 保留上游应用、动态库及后台助手的 Developer ID 签名。
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications/Tern.app" "$out/bin"
    cp -R . "$out/Applications/Tern.app"
    makeWrapper "$out/Applications/Tern.app/Contents/MacOS/tern" "$out/bin/tern" \
      --set SHELL ${lib.getExe bashInteractive}
    runHook postInstall
  '';

  meta = {
    description = "Stencil native terminal workspace with persistent sessions and OMP surfaces";
    homepage = "https://stencil.so/tern";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "tern";
  };
})
