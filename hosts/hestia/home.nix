{ config, lib, ... }:
{
  # hestia 是 WSL 终端主机，不启用 agenix secrets。
  # 关闭依赖 /etc/agenix 的 SSH homelab 块与 gh/github_token 配置。
  modules.ssh.homelab.enable = false;

  home.activation.configureGhAuth = lib.mkForce "";
  xdg.configFile."agenix/github_token".enable = lib.mkForce false;
  xdg.configFile."totp/secrets.conf".enable = lib.mkForce false;

  # WSL 没有桌面 D-Bus 会话，home-manager 的 dconf 激活必然失败，直接关闭。
  dconf.enable = lib.mkForce false;

  # WSL 无登录会话期间用户 systemd 未运行，HM 激活时不要启动用户单元
  # （登录后 tldr-update.timer 等会自动启动）。
  systemd.user.startServices = lib.mkForce false;
}