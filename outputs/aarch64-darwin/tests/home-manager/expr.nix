{
  myvars,
  lib,
  outputs,
}:
let
  username = myvars.username;
  hosts = [
    "artemis"
    "frieren"
  ];
in
lib.genAttrs hosts (
  name: outputs.darwinConfigurations.${name}.config.home-manager.users.${username}.home.homeDirectory
)
