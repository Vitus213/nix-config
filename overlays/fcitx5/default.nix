# 仅为 Fcitx 选择雾凇数据，其他 Rime 消费者保留上游默认值。
_: _: super: {
  fcitx5-rime = super.fcitx5-rime.override { rimeDataPkgs = [ super.rime-ice ]; };
}
