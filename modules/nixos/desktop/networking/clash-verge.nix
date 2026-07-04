{ pkgs, ... }:
{
  programs.clash-verge = {
    enable = true;
    package = pkgs.clash-verge-rev;
    autoStart = false;
    serviceMode = true;
    tunMode = true;
  };
}
