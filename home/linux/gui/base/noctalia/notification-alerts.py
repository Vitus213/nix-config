import json
import logging
import subprocess
import sys


def app_id(value):
    return value.casefold().removesuffix(".desktop")


def niri_snapshot(kind):
    result = subprocess.run(
        ["niri", "msg", "-j", kind],
        capture_output=True,
        text=True,
        check=True,
        timeout=5,
    )
    return json.loads(result.stdout)


def alert_notification(event, routes):
    if event.get("member") != "Notify":
        return
    data = event["payload"]["data"]
    hints = data[6]
    sources = [
        app_id(hints.get("desktop-entry", {}).get("data", "")),
        app_id(data[0]),
    ]
    workspace_name = next((routes[source] for source in sources if source in routes), None)
    workspaces = niri_snapshot("workspaces")
    if workspace_name:
        targets = {workspace["id"] for workspace in workspaces if workspace.get("name") == workspace_name}
    else:
        # Other applications follow their actual windows; no title/body matching.
        targets = {
            window["workspace_id"]
            for window in niri_snapshot("windows")
            if window.get("app_id") and app_id(window["app_id"]) in sources
        }
    for workspace in workspaces:
        if workspace["id"] not in targets or workspace["is_active"]:
            continue
        token = workspace.get("name") or str(workspace["idx"])
        subprocess.run(
            ["noctalia", "msg", "workspace-alert-add", token],
            capture_output=True,
            text=True,
            check=True,
            timeout=5,
        )


def main():
    with open(sys.argv[1], encoding="utf-8") as source:
        rules = json.load(source)
    routes = {app_id(name): workspace for workspace, names in rules.items() for name in names}
    match = "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"
    with subprocess.Popen(
        ["busctl", "--user", "--json=short", f"--match={match}", "monitor"],
        stdout=subprocess.PIPE,
        text=True,
    ) as monitor:
        for line in monitor.stdout:
            try:
                alert_notification(json.loads(line), routes)
            except (OSError, subprocess.SubprocessError, ValueError) as error:
                # Notification contents never enter the journal.
                logging.warning("Workspace alert failed: %s", error)
        return 1


if __name__ == "__main__":
    sys.exit(main())
