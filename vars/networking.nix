{ lib }:
rec {
  mainGateway = "192.168.111.1"; # main router
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
      ipv4 = "192.168.111.100";
      ipv6 = "fe80::f4e2:837b:6eb0:9184"; # Link-local Address
    };
    athena = {
      # Desktop PC (placeholder values)
      iface = "enp0s0";
      ipv4 = "192.168.111.101";
      ipv6 = "fe80::101"; # Link-local Address
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
    # define the host alias for remote builders
    # this config will be written to /etc/ssh/ssh_config
    #
    # Config format:
    #   Host —  given the pattern used to match against the host name given on the command line.
    #   HostName — specify nickname or abbreviation for host
    #   IdentityFile — the location of your SSH key authentication file for the account.
    # Format in details:
    #   https://www.ssh.com/academy/ssh/config
    extraConfig = (
      lib.attrsets.foldlAttrs (
        acc: host: val:
        acc
        + ''
          Host ${host}
            HostName ${val.ipv4}
            Port 22
        ''
      ) "" hostsAddr
    );

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
          hostNames = [ host ] ++ (lib.optional (hostsAddr ? host) hostsAddr.${host}.ipv4);
          publicKey = value.publicKey;
        })
        {
          # Define the root user's host key for remote builders, so that nix can verify all the remote builders

          # ==================================== Other SSH Service's Public Key =======================================

          # https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
          "github.com".publicKey =
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
        };
  };
}
