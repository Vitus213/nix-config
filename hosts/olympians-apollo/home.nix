{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;

  # athena 的 Vaultwarden 异地备份：拉取 backup-vaultwarden.service（每日 23:00）产出的
  # /var/backup/vaultwarden，按日期存放，保留 30 天。apollo 的 ~/.ssh/id_ed25519 已授权 athena root。
  vaultwardenBackupPull = pkgs.writeShellApplication {
    name = "vaultwarden-backup-pull";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      openssh
      rsync
    ];
    text = ''
      dest="$HOME/backups/vaultwarden"
      today="$dest/$(date +%F)"
      mkdir -p "$dest"
      chmod 700 "$dest"
      rsync -a --delete -e "ssh -o BatchMode=yes -o ConnectTimeout=15" \
        root@192.168.100.11:/var/backup/vaultwarden/ "$today/"
      find "$dest" -mindepth 1 -maxdepth 1 -type d -mtime +30 -exec rm -rf {} +
    '';
  };
in
{
  imports = [ ./magpie.nix ];

  # programs.ssh.matchBlocks."github.com".identityFile =
  #   "${config.home.homeDirectory}/.ssh/vitus-apollo";

  programs.nushell.extraConfig = lib.mkBefore ''
    source /etc/agenix/alias-for-work.nushell
  '';

  modules.desktop.nvidia.enable = true;
  modules.desktop.forceX11Compat.enable = true;
  modules.desktop.workApps.enable = true; # Slack、Notion、Linear

  xdg.configFile."niri/niri-hardware.kdl".source =
    mkSymlink "${config.home.homeDirectory}/nix-config/hosts/olympians-apollo/niri-hardware.kdl";

  systemd.user.services.vaultwarden-backup-pull = {
    Unit.Description = "Pull athena Vaultwarden backup";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe vaultwardenBackupPull;
    };
  };
  systemd.user.timers.vaultwarden-backup-pull = {
    Unit.Description = "Daily pull of athena Vaultwarden backup";
    Timer = {
      OnCalendar = "*-*-* 23:30:00"; # athena 23:00 备份之后
      Persistent = true; # apollo 关机错过时开机补跑
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
