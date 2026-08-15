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
  athena = mk true;
  generic = mk false;
  hermes = mk true;
}
