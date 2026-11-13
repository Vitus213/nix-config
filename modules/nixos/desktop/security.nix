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

  # 原生 Noctalia 包补丁固定使用 noctalia-lock，避免完整 login 栈的重复认证。
  # 保留一次 pam_unix 校验；原生认证还执行 account 检查，不打开 PAM session。
  # GNOME Keyring 仍由 greetd 登录阶段解锁。
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
