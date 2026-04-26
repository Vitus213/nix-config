{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # mitmproxy # http/https proxy tool
    wireshark # network analyzer
  ];

}
