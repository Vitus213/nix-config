{
  myvars,
  lib,
}:
let
  username = myvars.username;
  hosts = [
    "artemis"
    "frieren"
  ];
in
lib.genAttrs hosts (_: "/Users/${username}")
