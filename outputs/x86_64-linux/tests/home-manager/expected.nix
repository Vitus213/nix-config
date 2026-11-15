{ ... }:
let
  mk = sshHasHomelabBlock: { inherit sshHasHomelabBlock; };
in
{
  apollo = mk true;
  generic = mk false;
  athena = mk true;
  hermes = mk true;
}
