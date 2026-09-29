{ config, ... }:
{
  # 本地代理由 FlClash（mihomo 内核 GUI，手动安装的官方 dmg）提供，
  # mixed-port 7890 与下面 proxychains 配置一致。
  # 旧 clash-meta 内核包已随 Clash Verge 移除（FlClash 内置内核）。

  home.file.".proxychains/proxychains.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/home/darwin/proxy/proxychains.conf";
}
