_:
# nixpkgs 的 ccusage 20.0.17 早于 20.0.19/20.0.23/20.0.26 的 Codex/Claude 去重修复，会多算 token；
# 这里固定官方 npm 发布的静态二进制，供 agent-usage 统计使用。
(_: prev: {
  ccusage =
    let
      version = "20.0.39";
      platforms = {
        x86_64-linux = {
          npm = "linux-x64";
          hash = "sha256-M9DqwGb9XQUnceP/ZHTriRS6uOhlSffyGFAEQlMIl2s=";
        };
        aarch64-linux = {
          npm = "linux-arm64";
          hash = "sha256-PVZqdqbocMeWSfLqc/nF341UlrVzxkMtd98q9Hesv4M=";
        };
        x86_64-darwin = {
          npm = "darwin-x64";
          hash = "sha256-GjG7ri1nk6bt94HYL7KRpfbmUOiqda8qJ/IyouerTRo=";
        };
        aarch64-darwin = {
          npm = "darwin-arm64";
          hash = "sha256-K+k3Uc/cjFE0HXlpdEBTVFuNpno/RdZwT8nCQ2/z7Gc=";
        };
      };
      platform = platforms.${prev.stdenvNoCC.hostPlatform.system} or null;
    in
    if platform == null then
      prev.ccusage
    else
      prev.stdenvNoCC.mkDerivation {
        pname = "ccusage";
        inherit version;
        src = prev.fetchurl {
          url = "https://registry.npmjs.org/@ccusage/ccusage-${platform.npm}/-/ccusage-${platform.npm}-${version}.tgz";
          inherit (platform) hash;
        };
        sourceRoot = "package";
        dontConfigure = true;
        dontBuild = true;
        dontFixup = prev.stdenvNoCC.hostPlatform.isDarwin;
        installPhase = ''
          install -Dm755 bin/ccusage $out/bin/ccusage
        '';
        meta = {
          description = "Usage analysis for Claude Code, Codex and other coding agent CLIs";
          homepage = "https://github.com/ccusage/ccusage";
          license = prev.lib.licenses.mit;
          mainProgram = "ccusage";
          platforms = builtins.attrNames platforms;
        };
      };
})
