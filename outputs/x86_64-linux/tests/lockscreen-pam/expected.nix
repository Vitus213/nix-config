{
  lib,
  outputs,
}:
let
  expected = {
    authLineCount = 2;
    hasGnomeKeyring = false;
    hasNullokProbe = false;
    pamServiceEnv = true;
  };

  # 只覆盖带 noctalia-lock PAM 的桌面主机（终端主机如 hestia 不参与）
  desktopHosts =
    lib.filterAttrs (name: cfg: cfg.config.environment.etc ? "pam.d/noctalia-lock")
      outputs.nixosConfigurations;
in
lib.genAttrs (builtins.attrNames desktopHosts) (_: expected)