_: final: prev:
let
  capture = final.callPackage ./capture.nix { };
  legacyHook = builtins.head (
    builtins.match ".*LD_PRELOAD : [^:]*:([^ ]*/lib/wemeet/libhook.so).*" prev.wemeet.preFixup
  );
in
{
  wemeet = prev.wemeet.overrideAttrs (old: {
    # The pinned palette occupies existing PT_LOAD padding without a section.
    dontStrip = final.stdenv.hostPlatform.isx86_64;
    postInstall =
      (old.postInstall or "")
      + final.lib.optionalString final.stdenv.hostPlatform.isx86_64 ''
        ${final.python3}/bin/python3 ${./.}/theme.py --package-root "$out"
      '';
    preFixup =
      builtins.replaceStrings
        [ legacyHook "--set XDG_SESSION_TYPE x11" ]
        [
          "${capture}/lib/libwemeet-capture.so"
          # NVIDIA EGL 在 XWayland 视频窗口上 eglCreateWindowSurface 返回
          # EGL_NO_SURFACE(3005)，远端视频与共享黑屏；会话内切换 GLVND 厂商到
          # Mesa（软件渲染视频层），采集库经 SHM 兜底。见
          # documents/tencent-meeting.md 与 forum.archlinuxcn.org/t/topic/16745。
          ''
            --run 'if [[ -n ''${WAYLAND_DISPLAY:-} || ''${XDG_SESSION_TYPE:-} == wayland ]]; then
                        export WEMEET_WAYLAND_CAPTURE=1
                        vendor=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
                        if [[ -r $vendor ]]; then
                          export __EGL_VENDOR_LIBRARY_FILENAMES=$vendor __GLX_VENDOR_LIBRARY_NAME=mesa
                        fi
                      fi' --set XDG_SESSION_TYPE x11''
        ]
        old.preFixup
      + ''
        rm "$out/bin/wemeet"
        ln -s wemeet-xwayland "$out/bin/wemeet"
      '';
    passthru = (old.passthru or { }) // {
      desktopCapture = capture;
    };
  });
}
