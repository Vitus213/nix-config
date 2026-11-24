{
  config,
  lib,
  pkgs,
  ...
}:
##########################################################################
#
#  Install all apps and packages here.
#
#  NOTE: Your can find all available options in:
#    https://daiderd.com/nix-darwin/manual/index.html
#
##########################################################################
let
  # Homebrew Mirror
  # NOTE: is only useful when you run `brew install` manually! (not via nix-darwin)
  homebrew_mirror_env = {
    # nju mirror（2026-08-28 起启用；tuna/bfsu 的 bottles/git/pypi 端点实测 403 已失效）
    HOMEBREW_API_DOMAIN = "https://mirror.nju.edu.cn/homebrew-bottles/api";
    HOMEBREW_BOTTLE_DOMAIN = "https://mirror.nju.edu.cn/homebrew-bottles";
    HOMEBREW_BREW_GIT_REMOTE = "https://mirror.nju.edu.cn/git/homebrew/brew.git";
    HOMEBREW_CORE_GIT_REMOTE = "https://mirror.nju.edu.cn/git/homebrew/homebrew-core.git";
    HOMEBREW_PIP_INDEX_URL = "https://mirror.nju.edu.cn/pypi/web/simple";

  };

  homebrew_env_script = lib.attrsets.foldlAttrs (
    acc: name: value:
    acc + "\nexport ${name}=${value}"
  ) "" homebrew_mirror_env;
in
{
  environment.variables = {
    # Fix https://github.com/LnL7/nix-darwin/wiki/Terminfo-issues
    TERMINFO_DIRS = map (path: path + "/share/terminfo") config.environment.profiles ++ [
      "/usr/share/terminfo"
    ];
  }
  # Set variables for you to manually install homebrew packages.
  // homebrew_mirror_env;

  # Set environment variables for nix-darwin before run `brew bundle`.
  system.activationScripts.homebrew.text = lib.mkBefore ''
    echo >&2 '${homebrew_env_script}'
    ${homebrew_env_script}
  '';

  # Create /etc/zshrc that loads the nix-darwin environment.
  # this is required if you want to use darwin's default shell - zsh
  programs.zsh.enable = true;
  environment.shells = [
    pkgs.zsh
    pkgs.nushell # my custom shell
  ];

  # homebrew need to be installed manually, see https://brew.sh
  # https://github.com/LnL7/nix-darwin/blob/master/modules/homebrew.nix
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true; # Fetch the newest stable branch of Homebrew's git repo
      upgrade = true; # Upgrade outdated casks, formulae, and App Store apps
      # Leave unmanaged Homebrew packages alone during darwin activation.
      # This avoids activation failures on manually installed formulae like `steipete/tap/bird`.
      cleanup = "none";
    };

    taps = [
      "nikitabobko/tap" # aerospace - an i3-like tiling window manager for macOS
    ];

    brews = [
      "wget" # download tool
      "curl" # no not install curl via nixpkgs, it's not working well on macOS!
      "aria2" # download tool
      # https://github.com/rgcr/m-cli
      "m-cli" #  Swiss Army Knife for macOS
      # commands like `gsed` `gtar` are required by some tools
      "gnu-sed"
      "gnu-tar"
    ];

    # `brew install --cask`
    casks = [
      "squirrel-app" # input method for Chinese, rime-squirrel
      "zen" # browser - Zen Browser (Gecko based)

      # code editor
      "visual-studio-code"
      "zed"
      "nikitabobko/tap/aerospace" # an i3-like tiling window manager for macOS
      "ghostty" # terminal emulator

      # https://joplinapp.org/help/
      "joplin" # note taking app

      "tailscale-app" # tailscale macos app (with gui)

      "cc-switch" # configuration manager for AI coding agents

      # IM & audio & remote desktop & meeting
      "telegram"
      "zoom" # meeting

      "stats" # beautiful system status monitor in menu bar
      "jordanbaird-ice" # Powerful menu bar manager for macOS

    ];
  };
}
