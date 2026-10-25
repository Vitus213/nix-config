_:
# noctalia-qs 的 Niri IPC 只在 WorkspacesChanged 快照里读取 is_urgent，
# 忽略 WorkspaceUrgencyChanged，导致 urgent 清除后栏上工作区一直显示红色。
# 在 NiriService.qml 收到该事件时全量刷新工作区；升级后锚点失效会构建失败。
(_: prev: {
  noctalia-shell = prev.noctalia-shell.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace Services/Compositor/NiriService.qml \
        --replace-fail "    function onOverviewActiveChanged() {" \
      "    function onRawEvent(event) {
            if (event.type === \"WorkspaceUrgencyChanged\")
              Niri.refreshWorkspaces();
          }
          function onOverviewActiveChanged() {"
    '';
  });
})
