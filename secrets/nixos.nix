{
  lib,
  config,
  pkgs,
  agenix,
  mysecrets,
  myvars,
  ...
}:
with lib;
let
  cfg = config.modules.secrets;

  user_readable = {
    mode = "0500";
    owner = myvars.username;
  };
in
{
  imports = [
    agenix.nixosModules.default
  ];

  options.modules.secrets = {
    desktop.enable = mkEnableOption "NixOS Secrets for Desktops";

    preservation.enable = mkEnableOption "whether use preservation and ephemeral root file system";
  };

  config = mkIf cfg.desktop.enable {
    environment.systemPackages = [
      agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
    ];

    # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
    age.identityPaths =
      if cfg.preservation.enable then
        [
          "/home/${myvars.username}/.ssh/id_ed25519"
        ]
      else
        [
          "/etc/ssh/ssh_host_ed25519_key"
        ];

    age.secrets = {
      "nix-access-tokens" = {
        file = "${mysecrets}/nix-access-tokens.age";
      }
      // user_readable;

      "github_token" = {
        file = "${mysecrets}/github_token.age";
      }
      // user_readable;

      "ssh-key-romantic" = {
        file = "${mysecrets}/ssh-key-romantic.age";
      }
      // user_readable;

      "alias-for-work.nushell" = {
        file = "${mysecrets}/alias-for-work.nushell.age";
      }
      // user_readable;

      "totp-secrets.conf" = {
        file = "${mysecrets}/totp-secrets.conf.age";
      }
      // user_readable;

      # omp 各 provider 的 API key（与 omp-models.yml.in 的占位符对应）
      "omp-keys" = {
        file = "${mysecrets}/omp-keys.age";
      }
      // user_readable;
    };

    # place secrets in /etc/
    environment.etc = {
      "agenix/nix-access-tokens" = {
        source = config.age.secrets."nix-access-tokens".path;
        mode = "0400";
        user = myvars.username;
      };

      "agenix/github_token" = {
        source = config.age.secrets."github_token".path;
        mode = "0400";
        user = myvars.username;
      };

      "agenix/ssh-key-romantic" = {
        source = config.age.secrets."ssh-key-romantic".path;
        mode = "0600";
        user = myvars.username;
      };

      # Used by home-manager modules, so both the file and the symlink must be readable by the user.
      "agenix/alias-for-work.nushell" = {
        source = config.age.secrets."alias-for-work.nushell".path;
        mode = "0644";
      };

      # Used by noctalia TOTP scripts via ~/.config/totp/secrets.conf symlink.
      "agenix/totp-secrets.conf" = {
        source = config.age.secrets."totp-secrets.conf".path;
        mode = "0400";
        user = myvars.username;
      };
    };
  };
}
