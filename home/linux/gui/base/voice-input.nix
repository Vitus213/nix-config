{
  lib,
  config,
  pkgs,
  voiceless,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  # Voiceless 自带的 Home Manager 模块：常驻 daemon（模型常驻显存，快捷键
  # 只发一条 D-Bus 指令；同时在 http://127.0.0.1:8790/ 提供网页控制台）
  # + eww 浮层（~/.config/eww-voiceless，订阅 daemon 事件）。
  # 识别配置仍在 ~/.config/voiceless/config.toml（含密钥，不由 Nix 管理）。
  imports = [ voiceless.homeManagerModules.default ];

  programs.voiceless = {
    enable = true;
    # CUDA 版：GPU 跑 Qwen3-ASR 1.7B（transcribe.cpp，kernels 只编 sm_86 / RTX 30xx）。
    package = voiceless.packages.${system}.voiceless;
    service.enable = true;
    overlay.enable = true;
  };

  home.packages = [
    # 剪贴板兜底注入：把文本镜像到 X11 剪贴板，供微信等 XWayland 应用粘贴
    pkgs.xsel
    pkgs.xdotool
    pkgs.wtype
    pkgs.wl-clipboard
  ];

  # Fcitx5 桥接模块：voiceless 通过输入法直接提交文本、并把识别中的文字
  # 以预编辑显示在输入框里（inject.prefer = "fcitx5"）。用本机 pkgs 构建，
  # 保证与正在运行的 Fcitx5 C++ ABI 一致。
  i18n.inputMethod.fcitx5.addons = [
    (pkgs.callPackage "${voiceless}/nix/fcitx5-bridge.nix" { })
  ];

}
