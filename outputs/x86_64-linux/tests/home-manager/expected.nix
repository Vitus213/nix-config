{
  myvars,
  lib,
}:
let
  username = myvars.username;
  hosts = [
    "apollo-niri"
    "athena-niri"
  ];
in
lib.genAttrs hosts (_: "/home/${username}")
