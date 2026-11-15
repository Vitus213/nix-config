{ lib, ... }:
let
  expected = {
    authLineCount = 2;
    hasGnomeKeyring = false;
    hasNullokProbe = false;
  };

  # 固定桌面主机集合；缺失 PAM 服务必须失败，而不是静默缩小测试范围。
  desktopHosts = [
    "apollo"
    "athena"
    "generic"
  ];
in
lib.genAttrs desktopHosts (_: expected)
