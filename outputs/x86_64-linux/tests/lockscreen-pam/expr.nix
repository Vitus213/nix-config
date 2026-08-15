{
  lib,
  myvars,
  outputs,
}:
# 锁屏 PAM 服务回归测试（背景见 documents/lockscreen-pam.md）：
# 1. 每台 NixOS 主机都生成 /etc/pam.d/noctalia-lock
# 2. auth 段只有一次 pam_unix 验证 + deny（authLineCount = 2），
#    没有 gnome-keyring、没有 nullok 探测（unix-early）
# 3. noctalia-shell.service 注入 NOCTALIA_PAM_SERVICE=noctalia-lock
lib.mapAttrs (
  name: cfg:
  let
    etc = cfg.config.environment.etc;
    pamContent = builtins.readFile etc."pam.d/noctalia-lock".source;
    lines = lib.splitString "\n" pamContent;
    authLines = lib.filter (l: lib.hasPrefix "auth " l) lines;
    hmSvc =
      cfg.config.home-manager.users.${myvars.username}.systemd.user.services.noctalia-shell.Service;
  in
  {
    authLineCount = builtins.length authLines;
    hasGnomeKeyring = lib.any (l: lib.strings.hasInfix "gnome_keyring" l) lines;
    hasNullokProbe = lib.any (
      l: (lib.hasPrefix "auth optional" l) && (lib.strings.hasInfix "nullok" l)
    ) lines;
    pamServiceEnv = lib.elem "NOCTALIA_PAM_SERVICE=noctalia-lock" hmSvc.Environment;
  }
) outputs.nixosConfigurations
