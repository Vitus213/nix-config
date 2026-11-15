{ lib }:
rec {
  hostsAddr = {
    apollo = {
      ipv4 = "192.168.100.4";
    };
  };

  ssh = {
    # SSH host aliases for the machines in hostsAddr
    # this config will be written to /etc/ssh/ssh_config
    #
    # Config format:
    #   Host —  given the pattern used to match against the host name given on the command line.
    #   HostName — specify nickname or abbreviation for host
    #   IdentityFile — the location of your SSH key authentication file for the account.
    # Format in details:
    #   https://www.ssh.com/academy/ssh/config
    extraConfig =
      (lib.attrsets.foldlAttrs (
        acc: host: val:
        acc
        + ''
          Host ${host}
            HostName ${val.ipv4}
            Port 22
        ''
      ) "" hostsAddr)
      + ''
        Host artemis
          HostName 192.168.100.5
          Port 22
        Host athena
          HostName 192.168.100.11
          Port 22
        Host j1900
          HostName 192.168.100.3
          Port 22
      '';

    # this config will be written to /etc/ssh/ssh_known_hosts
    knownHosts =
      lib.attrsets.mapAttrs
        (host: value: {
          hostNames =
            value.hostNames or ([ host ] ++ (lib.optional (hostsAddr ? host) hostsAddr.${host}.ipv4));
          publicKey = value.publicKey;
        })
        {
          # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
          "github.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
          "apollo".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEMXO6/x1DtOnitqseH1jc34Nf489GCBFAgPAHyoWS7U";
          "athena" = {
            hostNames = [
              "athena"
              "192.168.100.11"
              "192.168.100.12"
            ];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPl9yGPLm/Oacc/MiteQswtAgYJI015TtbE0LAP9Chof";
          };
          "artemis" = {
            hostNames = [
              "artemis"
              "192.168.100.5"
            ];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPno/uSP9Aubo1zCQlZWDq2lif2MGHOTuY0fDnwv9AFY";
          };
          "j1900" = {
            hostNames = [
              "j1900"
              "192.168.100.3"
            ];
            publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE9QWImV7ez61ubrDDzhyG9y4AlCl8KYXd2TOWX9iync";
          };
        };
  };
}
