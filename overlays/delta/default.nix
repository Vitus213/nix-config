{ delta, ... }:
final: prev:
let
  system = prev.stdenv.hostPlatform.system;
  supported = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  # 上游 delta-nix 同时提供 bin/delta（CLI）与 bin/delta-app（GUI）。
  # bin/delta 与 nixpkgs 的 git-delta 冲突，这里把 CLI 改名为 delta-zed。
  upstream = delta.packages.${system}.delta;

  delta-zed =
    prev.runCommand "delta-zed-${upstream.version}"
      {
        nativeBuildInputs = [ prev.makeWrapper ];
        meta = upstream.meta // {
          mainProgram = "delta-app";
        };
      }
      ''
        mkdir -p "$out/bin" "$out/share/applications"
        ln -s ${upstream}/share/icons "$out/share/icons"

        makeWrapper ${upstream}/bin/delta "$out/bin/delta-zed"
        makeWrapper ${upstream}/bin/delta-app "$out/bin/delta-app"

        for desktop in ${upstream}/share/applications/*.desktop; do
          output="$out/share/applications/$(basename "$desktop")"
          sed "s|^Exec=.*|Exec=$out/bin/delta-zed open %U|" "$desktop" > "$output"
        done
      '';
in
{
  delta-zed =
    if builtins.elem system supported then
      delta-zed
    else
      throw "delta-zed is only packaged for ${builtins.concatStringsSep ", " supported}";
}
