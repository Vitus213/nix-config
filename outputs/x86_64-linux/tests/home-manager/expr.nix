{
  myvars,
  lib,
  outputs,
}:
# Home 层回归断言：
# 1. homeDirectory 正确
# 2. 生成的 ~/.ssh/config 是否含 homelab `192.168.*` 块——generic 必须为 false
#    （该主机无个人 secrets，/etc/agenix/ssh-key-romantic 不存在），其余主机为 true。
#    背景：此前 generic 用 `matchBlocks` mkForce 覆盖无效，块仍被渲染。
let
  username = myvars.username;
  check =
    hm:
    let
      sshConfig = hm.home.file.".ssh/config".text;
    in
    {
      homeDirectory = hm.home.homeDirectory;
      sshHasHomelabBlock = lib.hasInfix "Host 192.168.*" sshConfig;
    };
  hmUser = name: outputs.nixosConfigurations.${name}.config.home-manager.users.${username};
in
{
  apollo = check (hmUser "apollo");
  athena = check (hmUser "athena");
  generic = check (hmUser "generic");
  hermes = check outputs.homeConfigurations.hermes.config;
}
