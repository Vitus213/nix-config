{ myvars, ... }:
let
  username = myvars.username;
  mk = sshHasHomelabBlock: {
    homeDirectory = "/home/${username}";
    inherit sshHasHomelabBlock;
  };
in
{
  apollo = mk true;
  generic = mk false;
  athena = mk true;
  hermes = mk true;
}
