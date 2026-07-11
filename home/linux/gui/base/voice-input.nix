{
  lib,
  config,
  pkgs,
  ...
}:

let
  package = pkgs.voxtype-vulkan;
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
    initial_prompt = "以下是普通话与英文技术术语混合的桌面听写。请始终使用简体中文。"

    [output]
    mode = "type"
    fallback_to_clipboard = true
    driver_order = ["wtype", "clipboard"]
    type_delay_ms = 0
    pre_type_delay_ms = 100
    wait_for_modifier_release = false
    wtype_shift_prefix = true

    [output.post_process]
    command = "${lib.getExe' pkgs.opencc "opencc"} -c t2s.json"
    timeout_ms = 1000

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
      Environment = [ "VOXTYPE_VULKAN_DEVICE=nvidia" ];
      ExecStart = "${lib.getExe package} --no-hotkey daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };

    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
