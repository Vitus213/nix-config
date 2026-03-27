{ pkgs-master, ... }:
{
  # Use pkgs-master to get a newer clash-verge-rev version with potential fixes
  # for the tao-macros duplicate crate issue.
  programs.clash-verge = {
    enable = true;
    package = pkgs-master.clash-verge-rev;
    autoStart = false;
    serviceMode = true;
    tunMode = true;
  };
}
