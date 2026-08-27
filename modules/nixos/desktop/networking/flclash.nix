{
  pkgs,
  ...
}:
let
  # FlClash（chen08209/FlClash）——clash/mihomo 内核 GUI 客户端。
  # 官方 nixpkgs 无包、Homebrew 无 cask（macOS 需手动安装官方 dmg），
  # Linux 侧用官方 AppImage 打包。版本固定于下方 URL/hash，更新时同步本模块与
  # documents/application-version-audit.md。
  flclash = pkgs.appimageTools.wrapType2 {
    pname = "flclash";
    version = "0.8.96";

    src = pkgs.fetchurl {
      url = "https://github.com/chen08209/FlClash/releases/download/v0.8.96/FlClash-0.8.96-linux-amd64.AppImage";
      hash = "sha256-eodKrGznYI0mjSWpRpC5lcbAbd0cZoUWeMghyAUtPO4=";
    };
  };
in
{
  # 取代原 modules/nixos/desktop/networking/clash-verge.nix（programs.clash-verge）。
  # FlClash 的 mixed-port 默认 7890，与仓库内 proxychains 配置一致；TUN/service 模式
  # 在应用内管理，系统侧只负责安装。
  environment.systemPackages = [ flclash ];
}
