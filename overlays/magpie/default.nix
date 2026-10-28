_:
(_: prev: {
  magpie = prev.buildGoModule (finalAttrs: {
    pname = "magpie";
    version = "0.1.1846";

    src = prev.fetchFromGitHub {
      owner = "yetone";
      repo = "magpie";
      tag = "v${finalAttrs.version}";
      hash = "sha256-4J22GKJ+E06oqgEDcluQcgm75ytHplQ5TfXKdRcUUDc=";
    };
    vendorHash = "sha256-CSFUYQB28DBs0oQSObJEqu07+b7T7DKxINQVu+lHNUw=";

    # 保留 CLI、TUI 和 Web UI，不链接桌面窗口所需的 GTK / WebKit。
    tags = [ "nogui" ];
    env.CGO_ENABLED = "0";
    subPackages = [ "." ];
    ldflags = [
      "-s"
      "-w"
      "-X"
      "main.version=${finalAttrs.version}"
    ];
    doCheck = false;

    meta = {
      description = "Local model gateway and model switcher for AI agents";
      homepage = "https://github.com/yetone/magpie";
      license = prev.lib.licenses.mit;
      mainProgram = "magpie";
      platforms = prev.lib.platforms.linux;
    };
  });
})
