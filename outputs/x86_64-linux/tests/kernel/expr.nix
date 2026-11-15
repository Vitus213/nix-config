{
  lib,
  outputs,
}:
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name:
  lib.versions.majorMinor
    outputs.nixosConfigurations.${name}.config.boot.kernelPackages.kernel.version
)
