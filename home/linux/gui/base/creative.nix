{
  pkgs,
  ...
}:
{
  programs = {
    # live streaming
    obs-studio = {
      enable = pkgs.stdenv.hostPlatform.isx86_64;
      plugins = with pkgs.obs-studio-plugins; [
        obs-pipewire-audio-capture
      ];
    };
  };
}
