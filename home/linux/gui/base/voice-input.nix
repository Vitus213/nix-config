{
  lib,
  config,
  pkgs,
  syllune,
  ...
}:
let
  # 当前 ASR/文本整理全走 DashScope 云端（~/.config/syllune/config.toml），
  # 本地 sherpa-onnx 推理不使用，故装 CPU 版，不带 CUDA 工具链。
  # 若以后切回本地 GPU 推理，换回 .syllune 即可。
  syllunePackage = syllune.packages.${pkgs.stdenv.hostPlatform.system}.syllune-cpu;
in
{
  home.packages = [
    syllunePackage
    # overlay pill：eww daemon 常驻 + overlay pump 的 python3 解释器
    pkgs.eww
    # pump 脚本只需 PATH 上有任意 python3；降优先级让位给 editors 的
    # python313.withPackages env，避免 home-manager-path buildEnv 同名冲突
    (lib.lowPrio pkgs.python3)
    # 剪贴板注入：把文本镜像到 X11 剪贴板，供微信等 XWayland 应用粘贴
    pkgs.xsel
    pkgs.xdotool
    pkgs.wtype
    pkgs.wl-clipboard
  ];

  systemd.user.services.eww-syllune-overlay = {
    Unit = {
      Description = "eww daemon for the Syllune streaming overlay";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };

    Service = {
      # --no-daemonize：eww 默认 fork 后台化，父进程退出后 systemd Type=simple
      # 会误判服务已死；前台运行才能让 Restart=on-failure 真正生效
      ExecStart = "${lib.getExe pkgs.eww} daemon --no-daemonize";
      Restart = "on-failure";
      RestartSec = 3;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };

  systemd.user.services.syllune-web = {
    Unit = {
      Description = "Syllune history web console";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };

    Service = {
      ExecStart = "${lib.getExe syllunePackage} history serve";
      Restart = "on-failure";
      RestartSec = 3;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
