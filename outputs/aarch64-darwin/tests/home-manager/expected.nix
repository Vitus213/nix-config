{
  myvars,
  lib,
}:
let
  username = myvars.username;
  hosts = [
    "artemis"
  ];
in
lib.genAttrs hosts (_: "/Users/${username}")
