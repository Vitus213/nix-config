{
  config,
  lib,
  pkgs,
  ...
}:
let
  sshConfigPath = "${config.home.homeDirectory}/.ssh/config";
  materializedMarker = "# home-manager-materialized-ssh-config";
  cfg = config.modules.ssh;
in
{
  # Secret-free hosts (e.g. `generic`) disable this to drop the homelab block:
  # its IdentityFile /etc/agenix/ssh-key-romantic does not exist there.
  options.modules.ssh.homelab.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to include the homelab `192.168.*` block (ForwardAgent +
      /etc/agenix/ssh-key-romantic) in the generated ~/.ssh/config.
    '';
  };

  config = {
    programs.ssh = {
      enable = true;

      # default config
      enableDefaultConfig = false;
      settings = {
        "*" = {
          ForwardAgent = false;
          # "a private key that is used during authentication will be added to ssh-agent if it is running"
          AddKeysToAgent = "yes";
          Compression = true;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "no";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "no";
        };

        # Route GitHub SSH through its HTTPS endpoint when TCP/22 is unavailable.
        "github.com" = {
          HostName = "ssh.github.com";
          Port = 443;
          User = "git";
          HostKeyAlias = "github.com";
        };

        "apollo" = {
          HostName = "100.108.175.44";
          User = "vitus";
        };

        "artemis" = {
          HostName = "100.83.91.107";
          User = "vitus";
        };

        "athena" = {
          HostName = "100.104.233.76";
          User = "vitus";
        };
      }
      // lib.optionalAttrs cfg.homelab.enable {
        "192.168.*" = {
          # "allow to securely use local SSH agent to authenticate on the remote machine."
          # "It has the same effect as adding cli option `ssh -A user@host`"
          ForwardAgent = true;
          # "romantic holds my homelab~"
          IdentityFile = "/etc/agenix/ssh-key-romantic";
          IdentitiesOnly = true;
        };
      };
    };

    # OpenSSH rejects ~/.ssh/config when the Nix store owner is not root or the
    # current user. Materialize the generated config as a user-owned regular file.
    home.activation.prepareMaterializedSshConfig = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      target="${sshConfigPath}"

      if [ -f "$target" ] && [ ! -L "$target" ] \
        && ${pkgs.gnugrep}/bin/grep -qxF '${materializedMarker}' "$target"; then
        ${pkgs.coreutils}/bin/rm -f "$target"
      fi
    '';

    home.activation.materializeSshConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      target="${sshConfigPath}"

      if [ -L "$target" ]; then
        tmp="$target.tmp.$$"
        {
          printf '%s\n' '${materializedMarker}'
          ${pkgs.coreutils}/bin/cat "$target"
        } > "$tmp"
        ${pkgs.coreutils}/bin/chmod 0600 "$tmp"
        ${pkgs.coreutils}/bin/mv -f "$tmp" "$target"
      fi
    '';
  };
}
