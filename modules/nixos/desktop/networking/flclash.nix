{
  config,
  lib,
  myvars,
  pkgs,
  ...
}:
let
  cfg = config.modules.desktop.flclash;
  username = myvars.username;

  # Desktop installations without TUN retain the existing AppImage package.
  appImage = pkgs.appimageTools.wrapType2 {
    pname = "flclash";
    version = "0.8.96";

    src = pkgs.fetchurl {
      url = "https://github.com/chen08209/FlClash/releases/download/v0.8.96/FlClash-0.8.96-linux-amd64.AppImage";
      hash = "sha256-eodKrGznYI0mjSWpRpC5lcbAbd0cZoUWeMghyAUtPO4=";
    };
  };

  native = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "flclash";
    version = "0.9.4";

    src = pkgs.fetchurl {
      url = "https://github.com/chen08209/FlClash/releases/download/v${finalAttrs.version}/FlClash-${finalAttrs.version}-linux-amd64.deb";
      hash = "sha256-csa4ktdGeu/cZ82KOwUV+lozfojRktNyzaHCHJ0k1H8=";
    };

    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      dpkg
      jq
      makeWrapper
      wrapGAppsHook3
    ];
    buildInputs = with pkgs; [
      atk
      cairo
      fontconfig
      gdk-pixbuf
      glib
      gtk3
      harfbuzz
      libayatana-appindicator
      libepoxy
      libsecret
      libx11
      pango
      stdenv.cc.cc.lib
      wayland
    ];
    dontConfigure = true;
    dontBuild = true;
    dontWrapGApps = true;
    # The privileged Helper verifies the original static Core byte for byte.
    dontStrip = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb --extract "$src" .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin" "$out/opt"
      cp -r opt/FlClash "$out/opt/"
      cp -r usr/share "$out/"

      # JNI is only used on Android, and the copied artifact requires libjvm.
      rm "$out/opt/FlClash/lib/libdartjni.so"
      desktop="$out/share/applications/com.follow.clash.desktop"
      mv "$out/share/applications/FlClash.desktop" "$desktop"
      substituteInPlace "$desktop" --replace-fail 'Exec=FlClash %U' 'Exec=flclash %U'
      runHook postInstall
    '';

    preFixup = ''
      addAutoPatchelfSearchPath "$out/opt/FlClash/lib"
    '';

    postFixup = ''
      bundle="$out/opt/FlClash"
      makeWrapper "$bundle/FlClash" "$out/bin/flclash" \
        --prefix LD_LIBRARY_PATH : "$bundle/lib" \
        "''${gappsWrapperArgs[@]}"
      expected=$(jq -er '.coreSha256' "$bundle/manifest.json")
      actual=$(sha256sum "$bundle/FlClashCore")
      test "$expected" = "''${actual%% *}"
    '';

    meta = {
      description = "Cross-platform proxy client based on Mihomo";
      homepage = "https://github.com/chen08209/FlClash";
      license = lib.licenses.gpl3Only;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = [ "x86_64-linux" ];
      mainProgram = "flclash";
    };
  });
in
{
  options.modules.desktop.flclash.tun.enable = lib.mkEnableOption "the FlClash TUN helper";

  config = {
    environment.systemPackages = [ (if cfg.tun.enable then native else appImage) ];

    systemd.services.flclash-helper = lib.mkIf cfg.tun.enable {
      description = "FlClash TUN helper";
      wantedBy = [ "multi-user.target" ];
      after = [
        "nftables.service"
        "iptables.service"
      ];
      startLimitIntervalSec = 60;
      startLimitBurst = 5;

      serviceConfig = {
        Group = config.users.users.${username}.group;
        RuntimeDirectory = "flclash";
        RuntimeDirectoryMode = "0755";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = pkgs.writeShellScript "flclash-helper-start" ''
          set -eu
          export FLCLASH_HELPER_OWNER_UID="$(${lib.getExe' pkgs.coreutils "id"} -u ${lib.escapeShellArg username})"
          export FLCLASH_HELPER_OWNER_GID="$(${lib.getExe' pkgs.coreutils "id"} -g ${lib.escapeShellArg username})"
          exec ${native}/opt/FlClash/FlClashHelperService
        '';
      };
    };
  };
}
