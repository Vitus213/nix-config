{ config, lib, ... }:
{
  # make `npm install -g <pkg>` happey
  #
  # mainly used to install npm packages that updates frequently
  # such as gemini-cli, claude-code, etc.
  home.activation.backupExistingNpmrc = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    target="${config.home.homeDirectory}/.npmrc"
    if [ -e "$target" ] || [ -L "$target" ]; then
      backup="$target.home-manager.backup"
      if [ -e "$backup" ]; then
        backup="$backup.$(date +%s)"
      fi
      mv "$target" "$backup"
    fi
  '';

  home.file.".npmrc".text = ''
    prefix=${config.home.homeDirectory}/.npm
  '';
}
