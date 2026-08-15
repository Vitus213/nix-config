{
  pkgs,
  pkgs-x64,
  osConfig,
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
    # 监控/调优工具用法:
    #  Lutris - 高级选项 -> System options -> Command prefix 填 `mangohud`
    #  Steam  - 启动选项填 `mangohud %command%` / `gamemoderun %command%`
    # ==========================================================================
    home.packages = with pkgs; [
      # https://github.com/flightlessmango/MangoHud
      # FPS/温度/CPU/GPU 负载监控 overlay
      mangohud
      # GUI 安装 GE-Proton 等自定义 Proton 版本
      protonplus
      # 给 Wine 前缀安装各类运行库
      winetricks
      # https://github.com/Open-Wine-Components/umu-launcher
      # 统一的 Windows 游戏启动器
      umu-launcher
      gamescope
      gamemode
    ];

    # a GUI game launcher for Steam/GoG/Epic（战网系游戏的备用入口）
    # https://lutris.net/games?ordering=-popularity
    programs.lutris = {
      enable = true;
      defaultWinePackage = pkgs-x64.proton-ge-bin;
      steamPackage = osConfig.programs.steam.package;
      protonPackages = [ pkgs-x64.proton-ge-bin ];
      extraPackages = with pkgs; [
        winetricks
        gamescope
        gamemode
        mangohud
        umu-launcher
      ];
    };
  };
}
