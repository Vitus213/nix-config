{
  pkgs,
  nixpak,
  ...
}:
let
  callArgs = {
    mkNixPak = nixpak.lib.nixpak {
      inherit (pkgs) lib;
      inherit pkgs;
    };
    safeBind = sloth: realdir: mapdir: [
      (sloth.mkdir (sloth.concat' sloth.appDataDir realdir))
      (sloth.concat' sloth.homeDir mapdir)
    ];
  };
  wrapper = _pkgs: path: (_pkgs.callPackage path callArgs);
  qqPinned = pkgs.qq.overrideAttrs (_: {
    version = "3.2.29-2026-05-28";
    src = pkgs.fetchurl {
      url = "https://qqdl.gtimg.cn/qqfile/QQNT/9.9.31/release/00e6a3e7/QQ_3.2.29_260528_amd64_01.deb";
      hash = "sha256-HjgoB5ZzyUmUvA9HgNXYUoZHY5kgZZhi1J0cLyoZjiU=";
    };
  });
in
{
  # Add nixpaked Apps into nixpkgs, and reference them in home-manager or other nixos modules
  nixpkgs.overlays = [
    (_: super: {
      nixpaks = {
        qq = pkgs.callPackage ./qq.nix (callArgs // { qq = qqPinned; });
        telegram-desktop = wrapper super ./telegram-desktop.nix;
      };
    })
  ];
}
