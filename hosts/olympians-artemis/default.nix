_:
#############################################################
#
#  Artemis - MacBook Pro 2022 13-inch M2 16G.
#
#############################################################
let
  hostname = "artemis";
in
{
  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;
}
