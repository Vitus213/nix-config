{
  lib,
  stdenv,
  cmake,
  pkg-config,
  pipewire,
  glib,
  libglvnd,
  libdrm,
  libx11,
  libxext,
  libsForQt5,
}:
stdenv.mkDerivation {
  pname = "wemeet-desktop-capture";
  version = "1.0.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./CMakeLists.txt
      ./capture-hook.cpp
      ./capture-overlay.cpp
      ./capture-session.hpp
      ./capture-portal.hpp
      ./capture-gpu.hpp
      ./capture-frame.hpp
      ./capture-tests.cpp
    ];
  };
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [
    pipewire
    glib
    libglvnd
    libdrm
    libx11
    libxext
    libsForQt5.qtbase
  ];
  dontWrapQtApps = true;
  doCheck = true;
  meta = {
    description = "Portal screen capture with DMA-BUF import for Tencent Meeting";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
