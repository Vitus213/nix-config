_:
(_: prev: {
  # Temporary overlay until nixpkgs accepts bun 1.3.14.
  bun = prev.bun.overrideAttrs (old: rec {
    version = "1.3.14";

    src =
      passthru.sources.${prev.stdenvNoCC.hostPlatform.system}
        or (throw "Unsupported system: ${prev.stdenvNoCC.hostPlatform.system}");

    passthru = old.passthru // {
      sources = {
        "aarch64-darwin" = prev.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-darwin-aarch64.zip";
          hash = "sha256-2LliIYKK1vl6x6wKt+lYcjQa92MAHogD6CZ2UsJlJiA=";
        };
        "aarch64-linux" = prev.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-aarch64.zip";
          hash = "sha256-on/7Y6gxA3WDbg1vZorhf6jY0YuIw3yCHGUzGXOhmjs=";
        };
        "x86_64-darwin" = prev.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-darwin-x64-baseline.zip";
          hash = "sha256-PjWtb1OXGpg0v55nhuKt9ytfGSHMmpxf3gc9KXKUQHY=";
        };
        "x86_64-linux" = prev.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${version}/bun-linux-x64.zip";
          hash = "sha256-lR7iruhV8IWVruxiJSJqKY0/6oOj3NZGXAnLzN9+hI8=";
        };
      };
    };
  });
})
