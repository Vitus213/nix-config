# 为了不使用默认的 rime-data，改用雾凇拼音数据，这里需要 override
# 参考 https://github.com/NixOS/nixpkgs/blob/e4246ae1e7f78b7087dce9c9da10d28d3725025f/pkgs/tools/inputmethods/fcitx5/fcitx5-rime.nix
_:
(
  _: super:
  let
    rimeIce = super.stdenvNoCC.mkDerivation {
      pname = "rime-ice";
      version = "2026-06-21-3ec476e";

      src = super.fetchFromGitHub {
        owner = "iDvel";
        repo = "rime-ice";
        rev = "3ec476e9ca7f236d405481b6db6bb613754bc72d";
        hash = "sha256-YftR6KfbWZ4zpXLvO7V4Mo6GXeSJzTRioPf1sUxm6Lk=";
      };

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p "$out/share/rime-data"
        cp -r . "$out/share/rime-data"
        runHook postInstall
      '';

      meta = {
        description = "Rime Ice, a Simplified Chinese input schema collection for Rime";
        homepage = "https://github.com/iDvel/rime-ice";
        license = super.lib.licenses.gpl3Only;
      };
    };
  in
  {
    rime-data = rimeIce;
    rime-ice = rimeIce;
    fcitx5-rime = super.fcitx5-rime.override { rimeDataPkgs = [ rimeIce ]; };

    # used by macOS Squirrel
    rime-ice-squirrel = rimeIce;
  }
)
