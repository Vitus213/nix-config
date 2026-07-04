{
  lib,
}:
let
  hosts = [
    "apollo"
    "athena"
    "generic"
  ];
in
lib.genAttrs hosts (_: true)
