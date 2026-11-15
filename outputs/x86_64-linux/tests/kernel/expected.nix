{
  lib,
  outputs,
}:
let
  hostsNames = builtins.attrNames outputs.nixosConfigurations;
  expected = lib.genAttrs hostsNames (_: "6.18");
in
expected
