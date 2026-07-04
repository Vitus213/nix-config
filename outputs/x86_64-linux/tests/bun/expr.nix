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
in
lib.genAttrs hosts (
  name:
  outputs.nixosConfigurations.${name}.pkgs.lib.getVersion outputs.nixosConfigurations.${name}.pkgs.bun
)
