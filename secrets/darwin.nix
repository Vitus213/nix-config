{
  config,
  pkgs,
  agenix,
  mysecrets,
  myvars,
  ...
}:
{
  imports = [
    agenix.darwinModules.default
  ];

  # enable logs for debugging
  launchd.daemons."activate-agenix".serviceConfig = {
    StandardErrorPath = "/Library/Logs/org.nixos.activate-agenix.stderr.log";
    StandardOutPath = "/Library/Logs/org.nixos.activate-agenix.stdout.log";
  };

  environment.systemPackages = [
    agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
  ];

  # if you changed this key, you need to regenerate all encrypt files from the decrypt contents!
  age.identityPaths = [
    # Generate manually via `sudo ssh-keygen -A`
    "/etc/ssh/ssh_host_ed25519_key" # macOS, using the host key for decryption
  ];

  age.secrets =
    let
      user_readable = {
        mode = "0500";
        owner = myvars.username;
      };
    in
    {
      "nix-access-tokens" = {
        file = "${mysecrets}/nix-access-tokens.age";
      }
      # access-token needs to be readable by the user running the `nix` command
      // user_readable;

      "github_token" = {
        file = "${mysecrets}/github_token.age";
      }
      // user_readable;

      # alias-for-work
      "alias-for-work.nushell" = {
        file = "${mysecrets}/alias-for-work.nushell.age";
      }
      // user_readable;

      # omp 各 provider 的 API key（与 omp-models.yml.in 的占位符对应）
      "omp-keys" = {
        file = "${mysecrets}/omp-keys.age";
      }
      // user_readable;
    };

  # place secrets in /etc/
  # NOTE: this will fail for the first time. cause it's running before "activate-agenix"
  environment.etc = {
    # nix-access-tokens is consumed directly by modules/darwin/nix-core.nix via
    # `config.age.secrets.nix-access-tokens.path`, so it does not need an /etc mount.

    # The following secrets are used by home-manager modules
    # But nix-darwin doesn't support environment.etc.<name>.mode
    # So we need to change its mode manually
    "agenix/alias-for-work.nushell" = {
      source = config.age.secrets."alias-for-work.nushell".path;
    };
  };

  # activationScripts are executed every time you run `nixos-rebuild` / `darwin-rebuild` or boot your system
  system.activationScripts.postActivation.text = ''
    alias_path="/etc/agenix/alias-for-work.nushell"
    if [ -e "$alias_path" ] || [ -L "$alias_path" ]; then
      /usr/sbin/chown ${myvars.username} "$alias_path" || true
    fi
  '';
}
