{
  lib,
  outputs,
}:
let
  expected = {
    authLineCount = 2;
    hasGnomeKeyring = false;
    hasNullokProbe = false;
    pamServiceEnv = true;
  };
in
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (_: expected)
