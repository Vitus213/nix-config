{ lib }:
rec {
  mainGateway = "192.168.199.1"; # main router
  mainGateway6 = "fe80::5"; # main router's link-local address
  # use suzi as the default gateway
  # it's a subrouter with a transparent proxy
  proxyGateway = "192.168.5.178";
  proxyGateway6 = "fe80::8";
  nameservers = [
    # IPv4
    "100.100.100.100" # local DNS from current network
    "223.5.5.5" # AliDNS
    # IPv6
    "2400:3200::1" # AliDNS
    "2606:4700:4700::1111" # Cloudflare
  ];
  prefixLength = 24;

  hostsAddr = {
    # ============================================
    # Other VMs and Physical Machines
    # ============================================
    apollo = {
      # Desktop PC
      iface = "enp5s0";
      ipv4 = "192.168.100.4";
      ipv6 = "fe80::f4e2:837b:6eb0:9184"; # Link-local Address
      gateway = "192.168.100.1";
      gateway6 = "fe80::5";
    };
  };

  hostsInterface = lib.attrsets.mapAttrs (key: val: {
    interfaces."${val.iface}" = {
      useDHCP = false;
      ipv4.addresses = [
        {
          inherit prefixLength;
          address = val.ipv4;
        }
      ];
    };
  }) hostsAddr;

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
      '';

    # this config will be written to /etc/ssh/ssh_known_hosts
    knownHosts =
      # Update only the values of the given attribute set.
      #
      #   mapAttrs
      #   (name: value: ("bar-" + value))
      #   { x = "a"; y = "b"; }
      #     => { x = "bar-a"; y = "bar-b"; }
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
        };
  };
}
