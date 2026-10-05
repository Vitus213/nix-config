_:
# croc v11.5.4 标签携带过期 vendor/ 目录（与自身 go.mod 不一致，`go build`
# 校验 modules.txt 直接失败）；nixpkgs 的 vendorHash 本身与源码一致（已验证）。
# 删除 stale vendor，让 buildGoModule 的 FOD 重新提供依赖即可。
# 历史背景：此前 v10.4.5 曾因上游 re-tag 钉过 commit，升级 nixpkgs 后已无必要。
(_: prev: {
  croc = prev.croc.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + " rm -rf vendor";
  });
})
