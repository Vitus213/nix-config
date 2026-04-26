{
  lib,
  pkgs,
  ...
}:
{
  home.packages = lib.mkDefault [ ];

  programs = {
    # live streaming
    obs-studio = {
      enable = pkgs.stdenv.isx86_64;
      plugins = with pkgs.obs-studio-plugins; [
        # screen capture
        wlrobs
        obs-teleport
        droidcam-obs
        obs-vkcapture
        obs-gstreamer
        input-overlay
        obs-multi-rtmp
        obs-source-clone
        obs-shaderfilter
        obs-source-record
        obs-livesplit-one
        looking-glass-obs
        obs-vintage-filter
        obs-command-source
        obs-move-transition
        obs-backgroundremoval
        obs-pipewire-audio-capture
        obs-vaapi
        obs-3d-effect
      ];
    };
  };
}
