{
  config,
  pkgs,
  ...
}:
{
  # security with polkit
  security.polkit.enable = true;
  # security with gnome-kering
  services.gnome = {
    gnome-keyring.enable = true;
    # Use gnome keyring's SSH Agent
    # https://wiki.gnome.org/Projects/GnomeKeyring/Ssh
    gcr-ssh-agent.enable = false;
  };
  # seahorse is a GUI App for GNOME Keyring.
  programs.seahorse.enable = true;
  # The OpenSSH agent remembers private keys for you
  # so that you don’t have to type in passphrases every time you make an SSH connection.
  # Use `ssh-add` to add a key to the agent.
  programs.ssh.startAgent = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Noctalia 锁屏专用 PAM 服务（配合 home 层的 NOCTALIA_PAM_SERVICE 环境变量使用）。
  # 默认的 `login` 服务会跑完整栈：unix-early 探测 + gnome-keyring 解密 + 两次
  # pam_unix 验证，每一步都对 scrypt 哈希重新求值，导致解锁实测约 10 秒。
  # 这里只保留一次 pam_unix 校验，把解锁时间降到单次哈希验证的量级。
  # 注意：quickshell 的 PAM 子进程只调用 pam_authenticate，不触碰 session 阶段，
  # 因此锁屏不再顺带解锁 gnome-keyring；登录时 greetd 已负责解锁，会话内不受影响。
  security.pam.services.noctalia-lock = {
    unixAuth = true;
  };

  # gpg agent with pinentry
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
    enableSSHSupport = false;
    settings.default-cache-ttl = 4 * 60 * 60; # 4 hours
  };
}
