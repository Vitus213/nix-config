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
  cfg = config.modules.secrets.home;
in
{
  imports = [
    agenix.homeManagerModules.default
  ];

  options.modules.secrets.home = {
    enable = mkEnableOption "Home Manager secrets via agenix";
  };

  config = mkIf cfg.enable {
    home.packages = [
      agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
    ];

    age.secrets = {
      "alias-for-work.nushell" = {
        file = "${mysecrets}/alias-for-work.nushell.age";
      };
    };
  };
}
