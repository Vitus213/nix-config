{ ... }:
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

  # Nix is managed by the externally installed daemon (currently Lix on artemis).
  nix.enable = false;

  # 外部 Nix daemon 接管安装（nix.enable = false），nix-darwin 的
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

}
