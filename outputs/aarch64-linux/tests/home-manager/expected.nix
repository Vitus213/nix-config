{
  myvars,
  lib,
}:
let
  username = myvars.username;
  hosts = [ ];
in
lib.genAttrs hosts (_: "/home/${username}")
