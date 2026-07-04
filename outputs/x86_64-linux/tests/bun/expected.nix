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
lib.genAttrs hosts (_: "1.3.14")
