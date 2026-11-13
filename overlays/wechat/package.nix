# Linux-only backport of the nixpkgs WeChat recipe and source identities:
# https://github.com/NixOS/nixpkgs/tree/ea41ebe3e788f3f374e04885f4f60aca20efefed/pkgs/by-name/we/wechat
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,

  autoPatchelfHook,
  dpkg,
  makeShellWrapper,
  wrapGAppsHook3,

  alsa-lib,
  at-spi2-core,
  bzip2,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  glib,
  gtk3,
  libredirect,
  libice,
  libsm,
  libx11,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libglvnd,
  libjack2,
  libpulseaudio,
  libxcb,
  libxcb-keysyms,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  util-linuxMinimal,
  wayland,
  xkeyboard-config,
  zlib,
}:
let
  sources = {
    x86_64-linux = {
      version = "4.1.13.26";
      src = {
        url = "https://web.archive.org/web/20261012092649id_/https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb";
        hash = "sha256-oNuMru6NHmz+CqXOWHECcPjXSpD/SSD1Oj/CKqCVb+k=";
      };
      upstream = {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.deb";
        x-cos-hash-crc64ecma = "10867328176854818451";
        x-cos-version-id = "MTg0NDQ5NTIyNzg5NTUwNjk2Nzk";
      };
    };
    aarch64-linux = {
      version = "4.1.13.26";
      src = {
        url = "https://web.archive.org/web/20261012095035id_/https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb";
        hash = "sha256-N0cy7aiKbzp+TrMV5k5frHPvF5I9UE0kKWTxntG4DHU=";
      };
      upstream = {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.deb";
        x-cos-hash-crc64ecma = "14009050578420750826";
        x-cos-version-id = "MTg0NDQ5NTIyNzg5MzMyNjI0NTY";
      };
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "wechat";
  inherit (source) version;

  # Prefer the official URL only while it still identifies this pinned binary.
  # fetchurl verifies the same hash for either URL; otherwise use the archive.
  src = fetchurl {
    inherit (source.src) url hash;
    netrcPhase = ''
      touch netrc

      url=${lib.escapeShellArg source.upstream.url}
      crc=${lib.escapeShellArg source.upstream.x-cos-hash-crc64ecma}
      ver=${lib.escapeShellArg source.upstream.x-cos-version-id}

      if actual=$(curl -fsSIL -o /dev/null -w '%header{x-cos-hash-crc64ecma}:%header{x-cos-version-id}' "$url") && [[ "$actual" == "$crc:$ver" ]]; then
        urls=("$url")
      fi
    '';
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeShellWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    (lib.getLib stdenv.cc.cc) # libatomic and libstdc++

    dbus
    glib
    systemd

    at-spi2-core
    cairo
    fontconfig
    gtk3
    libxkbcommon
    xkeyboard-config
    pango

    libice
    libsm
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    libxcb-keysyms

    wayland
    libglvnd
    mesa

    alsa-lib
    libjack2
    libpulseaudio
    pipewire
    cups
    nspr
    nss
    bzip2
    expat
    zlib
  ];

  runtimeDependencies = [
    alsa-lib
    gtk3
    libglvnd
    libpulseaudio
    libxcursor
    pipewire
    systemd
    wayland
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp -r opt "$out/"
    cp -r usr/share "$out/"

    substituteInPlace "$out/share/applications/wechat.desktop" \
      --replace-fail "/usr/bin/wechat" "$out/bin/wechat"

    sed -i 's|^Icon=.*|Icon=wechat|' "$out/share/applications/wechat.desktop"

    runHook postInstall
  '';

  dontWrapGApps = true;

  preFixup = ''
    makeShellWrapper "$out/opt/wechat/wechat" "$out/bin/wechat" \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_PRELOAD : "${lib.getLib libredirect}/lib/libredirect.so" \
      --prefix NIX_REDIRECTS : "/usr/bin/lsblk=${lib.getExe' util-linuxMinimal "lsblk"}" \
      --set XKB_CONFIG_ROOT "${xkeyboard-config}/share/X11/xkb" \
      --set XLOCALEDIR "${libx11}/share/X11/locale" \
      --set QT_QPA_PLATFORM wayland \
      --set QT_IM_MODULE text-input-unstable-v3 \
      --set NIXOS_OZONE_WL 1 \
      --set-default QT_AUTO_SCREEN_SCALE_FACTOR 1
  '';

  postFixup = ''
    # ANGLE loads GL/EGL dynamically from the GPU process.
    patchelf --add-needed "${libglvnd}/lib/libGL.so.1" \
      --add-needed "${libglvnd}/lib/libEGL.so.1" \
      "$out/opt/wechat/RadiumWMPF/runtime/WeChatAppEx"

    # WMPF needs its own FFmpeg ABI rather than VLC's bundled libffmpeg.so.
    patchelf --replace-needed \
      libffmpeg.so \
      "$out/opt/wechat/RadiumWMPF/runtime/libffmpeg.so" \
      "$out/opt/wechat/RadiumWMPF/runtime/WeChatAppEx"

    wrapProgramShell "$out/opt/wechat/RadiumWMPF/runtime/WeChatAppEx" \
      --run '
        if [ -n "''${NIXOS_OZONE_WL:-}" ] && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          export GDK_BACKEND=wayland
          set -- --ozone-platform=wayland "$@"
        fi
      '
  '';

  passthru = {
    inherit sources source;
    upstreamRevision = "ea41ebe3e788f3f374e04885f4f60aca20efefed";
  };

  meta = {
    description = "Messaging and calling app";
    homepage = "https://www.wechat.com/en/";
    downloadPage = "https://linux.weixin.qq.com/en";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "wechat";
    platforms = lib.attrNames sources;
  };
}
