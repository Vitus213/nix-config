{
  config,
  lib,
  pkgs,
  ...
}:
###########################################################
#
# Ghostty Configuration
#
###########################################################
let
  formatValue =
    value:
    if builtins.isBool value then
      lib.boolToString value
    else if builtins.isFloat value || builtins.isInt value then
      toString value
    else if builtins.isString value then
      value
    else
      throw "Unsupported Ghostty setting value: ${builtins.typeOf value}";

  renderSettings =
    settings:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: value:
        lib.concatStringsSep "\n" (
          map (item: "${name} = ${formatValue item}") (if builtins.isList value then value else [ value ])
        )
      ) settings
    )
    + "\n";
in
{
  programs.ghostty = {
    enable = !pkgs.stdenv.isDarwin;
    enableBashIntegration = false;
    installBatSyntax = false;
    # installVimSyntax = true;
    settings = {
      font-family = "Maple Mono NF CN";
      font-size = 13;

      background-opacity = 0.93;
      # only supported on macOS;
      background-blur-radius = 10;
      scrollback-limit = 20000;

      # https://ghostty.org/docs/config/reference#command
      #  To resolve issues:
      #    1. https://github.com/ryan4yin/nix-config/issues/26
      #    2. https://github.com/ryan4yin/nix-config/issues/8
      #  Spawn a nushell in login mode via `bash`
      command = "${pkgs.bash}/bin/bash --login -c 'nu --login --interactive'";
    };
  }
  // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
    package = pkgs.ghostty; # the stable version
  };

  # Home Manager's Ghostty module validates configs by executing the package.
  # On Darwin we install Ghostty via Homebrew cask, so manage the config file directly.
  xdg.configFile."ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
    text = renderSettings config.programs.ghostty.settings;
  };
}
