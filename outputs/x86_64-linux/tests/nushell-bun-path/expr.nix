{
  lib,
  outputs,
}:
let
  hosts = [
    "apollo"
    "athena"
    "generic"
  ];
  username = "vitus";
in
lib.genAttrs hosts (
  name:
  let
    configSource =
      outputs.nixosConfigurations.${name}.config.home-manager.users.${username}.programs.nushell.configFile.source;
  in
  builtins.match ".*\\.cache/\\.bun/bin.*" (builtins.readFile configSource) != null
)
