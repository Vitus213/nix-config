_:
# Niri 26.04 仅发布 DMA-BUF；腾讯会议等只接收 SHM 的客户端无法协商屏幕流。
# 回移上游 PR #1791，固定提交范围；Niri 升级包含该修复后删除此 overlay。
(_: prev: {
  niri = prev.niri.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      (prev.fetchurl {
        name = "niri-screencast-shm.patch";
        url = "https://github.com/niri-wm/niri/compare/9e72e4917ca31baf4010496bf7f4aaf78d34d236...3871a3cd76a4168b2dc7c3da880fbe2702bd8900.diff";
        hash = "sha256-s8pciMdiGahY6fsA87ZxeRwFA7LwIZ4/cb5OZD64baA=";
      })
    ];
  });
})
