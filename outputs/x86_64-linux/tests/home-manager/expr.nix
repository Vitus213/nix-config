{
  myvars,
  lib,
  outputs,
}:
let
  username = myvars.username;
  hosts = [
    "apollo"
    "athena"
  ];
in
lib.genAttrs hosts (
  name: outputs.nixosConfigurations.${name}.config.home-manager.users.${username}.home.homeDirectory
)
