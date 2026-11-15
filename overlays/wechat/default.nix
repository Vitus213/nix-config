_: _: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  # 上游维护二进制来源、依赖和 WMPF 修复；这里只固定本桌面的 Wayland 行为。
  wechat = prev.wechat.overrideAttrs (old: {
    preFixup = (old.preFixup or "") + ''
      wrapProgramShell "$out/bin/wechat" \
        --set QT_QPA_PLATFORM wayland \
        --set QT_IM_MODULE text-input-unstable-v3 \
        --set NIXOS_OZONE_WL 1
    '';
  });
}
