{
  myvars,
  lib,
  outputs,
}:
let
  username = myvars.username;
  hosts = [
    "apollo-niri"
    "athena-niri"
    "ruby"
    "k3s-prod-1-master-1"
  ];
in
lib.genAttrs hosts (
  name: outputs.nixosConfigurations.${name}.config.home-manager.users.${username}.home.homeDirectory
)
