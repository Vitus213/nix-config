{
  lib,
  stdenv,
  requireFile,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  bashInteractive,
  git,
  zenity,
  glib,
  glib-networking,
  gsettings-desktop-schemas,
  gst_all_1,
  vulkan-loader,
  libglvnd,
  wayland,
  libxkbcommon,
  libxcb,
  gtk3,
  webkitgtk_4_1,
  libwpe,
  libwpe-fdo,
  pipewire,
  libpulseaudio,
}:
let
  runtimeLibraries = [
    vulkan-loader
    libglvnd
    wayland
    libxkbcommon
    libxcb
    glib
    gtk3
    webkitgtk_4_1
    libwpe
    libwpe-fdo
    pipewire
    libpulseaudio
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "tern-stencil";
  version = "0.9.21";

  src = requireFile {
    name = "Tern-${finalAttrs.version}-linux-x86_64.tar.gz";
    url = "https://build.stencil.so/tern";
    sha256 = "655cf7fac7ad1aac3153e4d0d9fe4772c147b5bf925d5a0fd10bb9beeb133adf";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  # 图形、浏览器、音频库由 dlopen 加载，ELF NEEDED 不包含它们。
  appendRunpaths = [
    (lib.makeLibraryPath runtimeLibraries)
    "/run/opengl-driver/lib"
  ];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 tern "$out/libexec/tern"
    makeWrapper "$out/libexec/tern" "$out/bin/tern" \
      --prefix PATH : ${
        lib.makeBinPath [
          git
          zenity
          glib.bin
        ]
      } \
      --set SHELL ${lib.getExe bashInteractive} \
      --prefix GIO_EXTRA_MODULES : ${glib-networking}/lib/gio/modules \
      --prefix XDG_DATA_DIRS : ${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name} \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.getLib gst_all_1.gst-plugins-base}/lib/gstreamer-1.0
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "so.stencil.tern";
      desktopName = "Tern";
      comment = "Stencil native terminal workspace";
      exec = "tern";
      icon = "utilities-terminal";
      terminal = false;
      categories = [
        "System"
        "TerminalEmulator"
      ];
      startupWMClass = "so.stencil.tern";
      extraConfig."X-TerminalArgExec" = "-e";
    })
    (makeDesktopItem {
      name = "so.stencil.tern.url";
      desktopName = "Tern";
      exec = "tern --open-url %u";
      icon = "utilities-terminal";
      noDisplay = true;
      terminal = false;
      mimeTypes = [ "x-scheme-handler/tern" ];
      startupWMClass = "so.stencil.tern";
    })
  ];

  meta = {
    description = "Stencil native terminal workspace with persistent sessions and OMP surfaces";
    homepage = "https://stencil.so/tern";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "tern";
  };
})
