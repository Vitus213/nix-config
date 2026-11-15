{
  pkgs,
  ...
}:
{
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  # set dpi for 4k monitor
  xresources.properties = {
    # dpi for Xorg's font
    "Xft.dpi" = 150;
    # or set a generic dpi
    "*.dpi" = 150;
  };

  # GTK 3/4 configuration; GTK 2 is retired by the current package set.
  gtk = {
    enable = true;
    gtk4.theme = null;

    font = {
      name = "Noto Sans";
      package = pkgs.noto-fonts;
      size = 11;
    };

    gtk2.enable = false;
  };
}
