{
  myvars,
  config,
  ...
}:
{
  # Don't allow mutation of users outside the config.
  users.mutableUsers = false;

  # security.sudo.extraRules = [
  #   {
  #     # Allow the primary user to run sudo non-interactively for tools that invoke it internally.
  #     users = [ myvars.username ];
  #     commands = [
  #       {
  #         command = "ALL";
  #         options = [ "NOPASSWD" ];
  #       }
  #     ];
  #   }
  # ];

  users.groups = {
    "${myvars.username}" = { };
    podman = { };
    wireshark = { };
    # for android platform tools's udev rules
    adbusers = { };
    dialout = { };
    # for openocd (embedded system development)
    plugdev = { };
    # misc
    uinput = { };
  };

  users.users."${myvars.username}" = {
    # we have to use initialHashedPassword here when using tmpfs for /
    inherit (myvars) initialHashedPassword;
    home = "/home/${myvars.username}";
    isNormalUser = true;
    extraGroups = [
      myvars.username
      "users"
      "wheel"
      "networkmanager" # for nmtui / nm-connection-editor
      "podman"
      "wireshark"
      "adbusers" # android debugging
      "libvirtd" # virt-viewer / qemu
      # Voiceless 按住说话：daemon 只读 /dev/input 里的 ScrollLock（不抢占按键）。
      # 代价：本用户的任何进程都能读取键盘事件。
      "input"
    ];
  };

  # root's ssh key are mainly used for remote deployment
  users.users.root = {
    inherit (myvars) initialHashedPassword;
    openssh.authorizedKeys.keys = myvars.mainSshAuthorizedKeys ++ myvars.secondaryAuthorizedKeys;
  };
}
