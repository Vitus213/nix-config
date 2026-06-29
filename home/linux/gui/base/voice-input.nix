{
  lib,
  config,
  pkgs,
  ...
}:

let
  package = pkgs.voxtype;
in
{
  home.packages = [
    package
    pkgs.wtype
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.playerctl
  ];

  xdg.configFile."voxtype/config.toml".text = ''
    state_file = "auto"

    [hotkey]
    enabled = false
    mode = "toggle"

    [audio]
    device = "default"
    sample_rate = 16000
    max_duration_secs = 60
    pause_media = false

    [whisper]
    model = "small"
    language = "zh"
    translate = false
    on_demand_loading = true
    initial_prompt = "Chinese and English mixed dictation for desktop text input."

    [output]
    mode = "type"
    fallback_to_clipboard = true
    driver_order = ["wtype", "clipboard"]
    type_delay_ms = 0
    pre_type_delay_ms = 100
    wait_for_modifier_release = false
    wtype_shift_prefix = true

    [output.notification]
    on_recording_start = true
    on_recording_stop = true
    on_transcription = true
    urgency = "normal"

    [osd]
    enabled = false
  '';

  systemd.user.services.voxtype = {
    Unit = {
      Description = "Voxtype voice input daemon";
      Documentation = "https://github.com/peteonrails/voxtype";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };

    Service = {
      ExecStart = "${lib.getExe package} --no-hotkey daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
