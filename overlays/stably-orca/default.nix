_:
(_: prev: {
  stably-orca =
    if prev.stdenvNoCC.hostPlatform.system == "x86_64-linux" then
      prev.callPackage (
        {
          appimageTools,
          fetchurl,
          lib,
          makeWrapper,
          nushell,
        }:
        let
          pname = "orca";
          version = "1.4.134";

          src = fetchurl {
            url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
            hash = "sha256-LkPMYi+prl1aKDzBJ02vCu2PXJAVmF3O2bOwXiQeoWw=";
          };

          appimageContents = appimageTools.extract {
            inherit pname version src;
          };
        in
        appimageTools.wrapAppImage {
          inherit pname version;
          src = appimageContents;
          nativeBuildInputs = [ makeWrapper ];
          extraBwrapArgs = [
            "--ro-bind-try /etc/agenix /etc/agenix"
          ];

          extraInstallCommands = ''
            desktop_file="$(find ${appimageContents} -name '*.desktop' -print -quit)"
            install -Dm644 "$desktop_file" "$out/share/applications/orca.desktop"
            sed -i -E 's|^Exec=.*|Exec=orca %U|' "$out/share/applications/orca.desktop"
            sed -i -E 's|^Icon=.*|Icon=orca|' "$out/share/applications/orca.desktop"

            if [[ -d ${appimageContents}/usr/share/icons ]]; then
              mkdir -p "$out/share/icons"
              cp -r ${appimageContents}/usr/share/icons/* "$out/share/icons/"
            fi

            icon_file="$(find ${appimageContents} \
              \( -name 'orca.png' -o -name 'orca.svg' \) \
              -print -quit)"
            if [[ -n "$icon_file" ]]; then
              install -Dm644 "$icon_file" "$out/share/pixmaps/$(basename "$icon_file")"
            fi

            wrapProgram "$out/bin/orca" --set SHELL "${lib.getExe nushell}"
          '';

          meta = {
            description = "ADE for working with a fleet of parallel coding agents";
            homepage = "https://github.com/stablyai/orca";
            license = lib.licenses.mit;
            mainProgram = "orca";
            platforms = [ "x86_64-linux" ];
          };
        }
      ) { }
    else
      throw "stably-orca is only packaged for x86_64-linux";
})
