{
  myvars,
  lib,
  outputs,
}:
# generic 不得渲染需要个人 secret 的 homelab SSH 块，其余主机必须保留。
# 背景：此前 generic 用 matchBlocks mkForce 覆盖无效，块仍被渲染。
let
  username = myvars.username;
  check =
    hm:
    let
      sshConfig = hm.home.file.".ssh/config".text;
    in
    {
      sshHasHomelabBlock = lib.hasInfix "Host 192.168.*" sshConfig;
    };
  hmUser = name: outputs.nixosConfigurations.${name}.config.home-manager.users.${username};
in
{
  apollo = check (hmUser "apollo");
  generic = check (hmUser "generic");
  athena = check (hmUser "athena");
  hermes = check outputs.homeConfigurations.hermes.config;
}
