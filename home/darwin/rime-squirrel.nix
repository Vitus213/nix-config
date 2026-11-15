{ pkgs, ... }:
{
  # Squirrel Input Method
  home.file."Library/Rime" = {
    # Rime Ice input method data
    source = "${pkgs.rime-ice}/share/rime-data";
    recursive = true;
  };
  # Separate managed patch: do not force-replace an existing user customization.
  home.file."Library/Rime/default.custom.yaml".text = ''
    patch:
      __include: rime_ice_suggestion:/
      schema_list:
        - schema: double_pinyin_flypy
  '';
}
