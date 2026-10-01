{ config, ... }:
{
  ###################################################################################
  #
  #  Core configuration for nix-darwin
  #
  #  All the configuration options are documented here:
  #    https://daiderd.com/nix-darwin/manual/index.html#sec-options
  #
  # History Issues:
  #  1. Fixed by replace the determined nix-installer by the official one:
  #     https://github.com/LnL7/nix-darwin/issues/149#issuecomment-1741720259
  #
  ###################################################################################

  # Determinate uses its own daemon to manage the Nix installation that
  # conflicts with nix-darwin's native Nix management. so we should disable this option.
  nix.enable = false;

  # Disable auto-optimise-store because of this issue:
  #   https://github.com/NixOS/nix/issues/7273
  # "error: cannot link '/nix/store/.tmp-link-xxxxx-xxxxx' to '/nix/store/.links/xxxx': File exists"
  nix.settings.auto-optimise-store = false;

  # Determinate Nix 接管 nix daemon（nix.enable = false），nix-darwin 的
  # nix.gc 模块不可用（断言要求 nix.enable，且 dates 已废弃）。改用 launchd
  # 每周日 03:00 定时 gc，策略与 NixOS 侧（modules/nixos/base/nix.nix）对齐：
  # 清理 7 天前的死路径，保留回滚窗口。
  launchd.user.agents."nix-gc" = {
    serviceConfig = {
      ProgramArguments = [
        "/nix/var/nix/profiles/default/bin/nix-collect-garbage"
        "--delete-older-than"
        "7d"
      ];
      StartCalendarInterval = [
        {
          Hour = 3;
          Minute = 0;
          Weekday = 0;
        }
      ];
    };
  };

  system.stateVersion = 5;

  nix.extraOptions = ''
    !include ${config.age.secrets.nix-access-tokens.path}
  '';
}
