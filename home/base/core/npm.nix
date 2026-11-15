{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    bun # omp 等用户级 `bun install -g` 的运行时
    pnpm
  ];

  # make `npm install -g <pkg>` happy
  #
  # mainly used to install npm packages that updates frequently
  # such as gemini-cli, claude-code, etc.
  home.activation.backupExistingNpmrc =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
      ''
        target="${config.home.homeDirectory}/.npmrc"
        if [ -L "$target" ]; then
          case "$(${pkgs.coreutils}/bin/readlink "$target")" in
            /nix/store/*-home-manager-files/.npmrc) target="" ;;
          esac
        fi
        if [ -n "$target" ] && { [ -e "$target" ] || [ -L "$target" ]; }; then
          backup="$target.home-manager.backup"
          if [ -e "$backup" ] || [ -L "$backup" ]; then
            echo "Refusing to replace existing npm configuration backup: $backup" >&2
            false
          else
            run ${pkgs.coreutils}/bin/mv -- "$target" "$backup"
          fi
        fi
      '';

  home.file.".npmrc" = {
    force = true;
    text = ''
      prefix=${config.home.homeDirectory}/.npm
    '';
  };
}
