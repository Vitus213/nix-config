{
  # btrbk is only useful for hosts with a real Btrfs subvolume layout.
  # Current desktop hosts use ext4 persistence, so keep the old Btrfs template
  # disabled until a host explicitly restores /btr_pool/@persistent.

  # services.btrbk.instances.btrbk = {
  #   onCalendar = "Tue,Sat *-*-* 3:45:20";
  #   settings = {
  #     snapshot_preserve = "7d";
  #     snapshot_preserve_min = "2d";
  #
  #     target_preserve = "9d 4w 2m";
  #     target_preserve_min = "no";
  #
  #     volume = {
  #       "/btr_pool" = {
  #         subvolume = {
  #           "@persistent" = {
  #             snapshot_create = "always";
  #           };
  #         };
  #
  #         # target = "/snapshots";
  #       };
  #     };
  #   };
  # };
}
