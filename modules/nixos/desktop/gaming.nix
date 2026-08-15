{
  pkgs,
  pkgs-x64,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.modules.desktop.gaming;
in
{
  options.modules.desktop = {
    gaming = {
      enable = mkEnableOption "Install Game Suite(steam, lutris, etc)";
    };
  };

  config = mkIf cfg.enable {
    # ==========================================================================
    # Gaming on Linux
    #
    #   <https://www.protondb.com/> 可查各游戏的 Linux 兼容评级。
    #   入门指南: <https://www.reddit.com/r/linux_gaming/wiki/faq/>
    #
    # Overwatch 2 等 BattlEye 已支持 Proton 的游戏，Steam + Proton 可直接进游戏
    # （Steam 设置里启用 Steam Play）。Apex Legends 截至 2026-08 仍被 EA 反作弊
    # 封锁（E111000B），Linux 原生不可玩，只能云游戏或等解禁。
    # ==========================================================================

    # Games installed by Steam works fine on NixOS, no other configuration needed.
    # https://github.com/NixOS/nixpkgs/blob/master/doc/packages/steam.section.md
    programs.steam = {
      enable = true;
      # 32 位兼容库等游戏运行时依赖 x86_64 包集合
      package = pkgs-x64.steam;
      # https://github.com/ValveSoftware/gamescope
      # 从 display-manager 进入 GameScope 驱动的 Steam 会话，
      # 修复分辨率缩放与拉伸比例问题
      gamescopeSession.enable = true;
      # protontricks: 对 Proton 游戏运行 winetricks 的简单封装
      protontricks.enable = true;
      # 将 X11 输入事件翻译为 uinput（Wayland 下使用 Steam Input）
      extest.enable = true;
      fontPackages = [
        pkgs.wqy_zenhei # Need by steam for Chinese
      ];
    };

    # 按需优化系统性能（CPU governor/优先级等）
    # https://github.com/FeralInteractive/GameMode
    programs.gamemode.enable = true;
  };
}
