{
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
        mode = "0400";
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

      # WakaTime API key，home 侧直接读 /run/agenix/wakatime-api-key
      "wakatime-api-key" = {
        file = "${mysecrets}/wakatime-api-key.age";
      }
      // user_readable;
    };

}
