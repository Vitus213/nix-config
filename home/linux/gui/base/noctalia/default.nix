{
  lib,
  config,
  pkgs,
  wallpapers,
  noctalia-plugins,
  ...
}:

let
  package = pkgs.noctalia;
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
  confPath = "${config.home.homeDirectory}/nix-config/home/linux/gui/base/noctalia";
  tomlFormat = pkgs.formats.toml { };
in
{

  home.packages = [
    package
    pkgs.qt6Packages.qt6ct # for icon theme
    pkgs.app2unit # Launch Desktop Entries (or arbitrary commands) as Systemd user units
  ]
  ++ (lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    pkgs.gpu-screen-recorder # recoding screen
  ]);

  home.file."Pictures/Wallpapers".source = wallpapers + "/jpg";
  xdg.configFile = {
    "noctalia/config.toml".source = mkSymlink "${confPath}/config/config.toml";
    "noctalia/scripts/totp".source = mkSymlink "${confPath}/config/scripts/totp";
    "noctalia/plugins.toml".source = tomlFormat.generate "noctalia-plugins.toml" {
      plugins = {
        enabled = [
          "thepunkoff/pomodoro"
          "vitus/desktop"
        ];
        auto_update = "none";
        source = [
          {
            name = "community-pinned";
            kind = "path";
            location = toString noctalia-plugins;
            enabled = true;
          }
        ];
      };
    };
    "qt6ct/qt6ct.conf".source = mkSymlink "${confPath}/qt6ct.conf";
    "totp/secrets.conf" = {
      source = mkSymlink "/etc/agenix/totp-secrets.conf";
      force = true;
    };
  };

  xdg.dataFile."noctalia/plugins/desktop".source = mkSymlink "${confPath}/plugins/desktop";

  # 只移除本仓库旧的受管目录链接，其他目标视为冲突。
  home.activation.migrateNoctaliaConfig = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    noctalia_config="${config.xdg.configHome}/noctalia"
    if [ -L "$noctalia_config" ]; then
      target="$(readlink -f "$noctalia_config")"
      if [ "$target" = "${confPath}/config" ]; then
        run unlink "$noctalia_config"
      else
        echo "Noctalia config link conflicts with managed migration: $noctalia_config -> $target" >&2
        exit 1
      fi
    fi
  '';

  systemd.user.services.noctalia = {
    Unit = {
      Description = "Noctalia Shell - Wayland desktop shell";
      Documentation = "https://github.com/noctalia-dev/noctalia/tree/v5.5.0";
      PartOf = [ "graphical-session.target" ];
      After = [ "niri.service" ];
      Before = [ "graphical-session.target" ];
    };

    Service = {
      Type = "notify";
      ExecStart = lib.getExe package;
      Restart = "on-failure";

      Environment = [ "TERMINAL=kitty" ];
    };

    Install.WantedBy = [ "niri.service" ];
  };
}
