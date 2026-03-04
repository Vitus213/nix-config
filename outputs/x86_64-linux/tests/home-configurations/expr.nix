{
  lib,
  outputs,
}:
let
  hosts = [ "hermes" ];
in
lib.genAttrs hosts (name: outputs.homeConfigurations.${name}.config.targets.genericLinux.enable)
