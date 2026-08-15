{
  config,
  pkgs,
  ...
}:
{
  #############################################################
  #
  #  Basic settings for development environment
  #
  #  Please avoid to install language specific packages here(globally),
  #  instead, install them:
  #     1. per IDE, such as `programs.neovim.extraPackages`
  #     2. per-project, using https://github.com/the-nix-way/dev-templates
  #
  #############################################################

  home.packages = with pkgs; [
    just
    colmena # nixos's remote deployment tool
    herdr # persistent terminal runtime for coding agents

    tokei # count lines of code, alternative to cloc

    sqlite

    # misc
    gitleaks
  ];

  xdg.configFile."herdr/config.toml".text = ''
    onboarding = false

    [terminal]
    default_shell = "${config.programs.nushell.package}/bin/nu"
    shell_mode = "login"

    # 后台 agent 完成/需要输入时的通知；herdr = 应用内 toast。
    # 本机无 dunst/mako 等系统通知守护进程，system/terminal 模式不可靠。
    [ui.toast]
    delivery = "herdr"
    delay_seconds = 1
  '';

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;

      enableZshIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
    };
  };
}
