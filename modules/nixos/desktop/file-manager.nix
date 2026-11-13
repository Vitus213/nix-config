{
  dux-files,
  myvars,
  ...
}:
{
  imports = [ dux-files.nixosModules.dux-files ];

  programs.dux-files = {
    enable = true;
    systemd.enable = true;
  };

  systemd.user.services.dfiles = {
    # D-Bus/systemd 启动不依赖交互 shell 的 Qt 后端设置。
    environment.QT_QPA_PLATFORM = "wayland";
    # Open With 和打开终端需要找到系统及 Home Manager 安装的应用。
    path = [
      "/run/current-system/sw"
      "/etc/profiles/per-user/${myvars.username}"
    ];
  };
}
