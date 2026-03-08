{
  lib,
}:
let
  hosts = [ "hermes" ];
in
lib.genAttrs hosts (_: true)
