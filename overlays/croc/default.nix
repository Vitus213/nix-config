_:
(_: prev: {
  # Work around an upstream croc v10.4.5 source archive hash drift in nixpkgs.
  croc = prev.croc.overrideAttrs (_: {
    src = prev.fetchFromGitHub {
      owner = "schollz";
      repo = "croc";
      rev = "57e5fd7cef0466e3dbe086e18d00fc9e40e4dffa";
      hash = "sha256-u262LwHUL6+rPE7nzIda7W5dAXaikQ/cKwtUEIbcbH0=";
    };
  });
})
