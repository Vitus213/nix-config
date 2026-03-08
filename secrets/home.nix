{
  lib,
  config,
  pkgs,
  agenix,
  mysecrets,
  ...
}:
with lib;
let
  cfg = config.modules.secrets;
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;

  # Home-Manager agenix module does not support owner/group options.
  # Decrypted files are created by the current user, so `mode` is enough.
  user_readable = {
    mode = "0400";
  };
in
{
  imports = [
    agenix.homeManagerModules.default
  ];

  options.modules.secrets = {
    home.enable = mkEnableOption "Home Manager secrets via agenix";
  };

  config = mkIf cfg.home.enable (mkMerge [
    {
      home.packages = [
        agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
      ];

      # If you changed keys here, secrets in `mysecrets` need to be re-encrypted.
      age.identityPaths = [
        "${config.home.homeDirectory}/.ssh/hermes"
        "${config.home.homeDirectory}/.ssh/id_ed25519"
        "${config.home.homeDirectory}/.ssh/id_rsa"
      ];

      assertions = [
        {
          assertion = config.age.identityPaths != [ ];
          message = "modules.secrets.home.enable is true, but age.identityPaths is empty.";
        }
      ];
    }

    {
      age.secrets = {
        "alias-for-work.nushell" = {
          file = "${mysecrets}/alias-for-work.nushell.age";
        }
        // user_readable;

        "github_token" = {
          file = "${mysecrets}/nix-access-tokens.age";
        }
        // user_readable;
      };

      xdg.configFile."agenix/github_token".source = mkSymlink config.age.secrets."github_token".path;
    }
  ]);
}
