{
  myvars,
  lib,
}:
let
  username = myvars.username;
  hosts = [
    "apollo"
    "athena"
  ];
in
lib.genAttrs hosts (_: "/home/${username}")
