{
  config,
  lib,
  pkgs,
  myvars,
  ...
}:
let
  ghUser = myvars.githubUsername or myvars.username;
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
  githubTokenPath =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "/run/agenix/github_token"
    else
      "/etc/agenix/github_token";
in
{
  # Unified token path for gh auth generation.
  # On macOS this points to /run/agenix/github_token because the secret is provided by nix-darwin agenix.
  # HM-only hosts can override this in `secrets/home.nix`.
  xdg.configFile."agenix/github_token" = {
    source = lib.mkDefault (mkSymlink githubTokenPath);
    force = true;
  };

  # Only retire the legacy Home Manager link; keep handwritten Git configuration.
  home.activation.removeExistingGitconfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    target="${config.home.homeDirectory}/.gitconfig"
    if [ -L "$target" ]; then
      case "$(${pkgs.coreutils}/bin/readlink "$target")" in
        /nix/store/*-home-manager-files/.gitconfig)
          run ${pkgs.coreutils}/bin/rm -- "$target"
          ;;
      esac
    fi
  '';

  # Migrate pre-existing github_token files or legacy symlinks into HM management.
  home.activation.backupExistingGithubToken =
    lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ]
      ''
        target="${config.xdg.configHome}/agenix/github_token"
        if [ -L "$target" ]; then
          case "$(${pkgs.coreutils}/bin/readlink "$target")" in
            /nix/store/*-home-manager-files/.config/agenix/github_token|/nix/store/*-hm_github_token|"${githubTokenPath}")
              target=""
              ;;
          esac
        fi
        if [ -n "$target" ] && { [ -e "$target" ] || [ -L "$target" ]; }; then
          backup="$target.home-manager.backup"
          if [ -e "$backup" ] || [ -L "$backup" ]; then
            echo "Refusing to replace existing GitHub token backup: $backup" >&2
            false
          else
            run ${pkgs.coreutils}/bin/mv -- "$target" "$backup"
          fi
        fi
      '';

  # GitHub CLI tool
  # https://cli.github.com/manual/
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "https";
      prompt = "enabled";
      aliases = {
        co = "pr checkout";
        pv = "pr view";
      };
    };
  };

  # Generate gh auth config from an agenix secret at activation time.
  # This avoids embedding the token into the Nix store.
  home.activation.configureGhAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        token_file="${config.xdg.configHome}/agenix/github_token"
        hosts_file="${config.xdg.configHome}/gh/hosts.yml"

        if [ -r "$token_file" ]; then
          token="$(${pkgs.coreutils}/bin/head -n 1 "$token_file" | ${pkgs.gnused}/bin/sed 's/[[:space:]]*$//')"
          if [ -n "$token" ]; then
            run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$hosts_file")"
            if [ -e "$hosts_file" ] || [ -L "$hosts_file" ]; then
              run ${pkgs.coreutils}/bin/rm -f "$hosts_file"
            fi
            if [ ! -v DRY_RUN ]; then
              (umask 077; cat > "$hosts_file" <<EOF
    github.com:
        user: ${ghUser}
        oauth_token: $token
        git_protocol: https
    EOF
              )
            fi
          fi
          unset token
        fi
  '';

  programs.git = {
    enable = true;
    signing.format = null;
    lfs.enable = true;

    # signing = {
    #   key = "xxx";
    #   signByDefault = true;
    # };

    includes = [
      {
        # use different email & name for work:
        #
        # [user]
        #   email = "xxx@xxx.com"
        #   name = "Your Name"
        path = "~/work/.gitconfig";
        condition = "gitdir:~/work/";
      }
    ];

    settings = {
      user.email = myvars.useremail;
      user.name = myvars.userfullname;

      init.defaultBranch = "main";
      core.quotePath = false; # 显示中文文件名而不是转义序列
      trim.bases = "develop,master,main"; # for git-trim
      push.autoSetupRemote = true;
      pull.rebase = true;
      log.date = "iso"; # use iso format for date

      # Keep GitHub remotes on HTTPS so `gh` token auth is used instead of SSH.
      #
      # url = {
      #   "ssh://git@github.com/${ghUser}" = {
      #     insteadOf = "https://github.com/${ghUser}";
      #   };
      # };

      credential = {
        # Clear any inherited helpers and force GitHub HTTPS auth through `gh`.
        "https://github.com".helper = [
          ""
          "${pkgs.gh}/bin/gh auth git-credential"
        ];
        "https://gist.github.com".helper = [
          ""
          "${pkgs.gh}/bin/gh auth git-credential"
        ];
      };

      alias = {
        # common aliases
        br = "branch";
        co = "checkout";
        st = "status";
        ls = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate";
        ll = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate --numstat";
        cm = "commit -m"; # commit via `git cm <message>`
        ca = "commit -am"; # commit all changes via `git ca <message>`
        dc = "diff --cached";

        amend = "commit --amend -m"; # amend commit message via `git amend <message>`
        unstage = "reset HEAD --"; # unstage file via `git unstage <file>`
        merged = "branch --merged"; # list merged(into HEAD) branches via `git merged`
        unmerged = "branch --no-merged"; # list unmerged(into HEAD) branches via `git unmerged`
        nonexist = "remote prune origin --dry-run"; # list non-exist(remote) branches via `git nonexist`

        # delete merged branches except master & dev & staging
        #  `!` indicates it's a shell script, not a git subcommand
        delmerged = ''! git branch --merged | egrep -v "(^\*|main|master|dev|staging)" | xargs git branch -d'';
        # delete non-exist(remote) branches
        delnonexist = "remote prune origin";

        # aliases for submodule
        update = "submodule update --init --recursive";
        foreach = "submodule foreach";
      };
    };
  };

  # A syntax-highlighting pager for git, diff, grep, and blame output
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      diff-so-fancy = true;
      line-numbers = true;
      true-color = "always";
      # features => named groups of settings, used to keep related settings organized
      # features = "";
    };
  };

  # Git terminal UI (written in go).
  programs.lazygit.enable = true;

}
