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
    pkgs.python3
    # 剪贴板注入：把文本镜像到 X11 剪贴板，供微信等 XWayland 应用粘贴
    pkgs.xsel
  ];

  systemd.user.services.eww-syllune-overlay = {
    Unit = {
      Description = "eww daemon for the Syllune streaming overlay";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };

    Service = {
      ExecStart = "${lib.getExe pkgs.eww} daemon";
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
