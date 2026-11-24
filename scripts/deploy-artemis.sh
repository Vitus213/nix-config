#!/bin/sh
set -eu
umask 077

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

mode=${1:-switch}
case "$mode" in
  sync|build|switch|default|debug) ;;
  *) fail "Artemis deployment mode must be sync, build, switch, or debug" ;;
esac

[ "$(/usr/bin/uname -s)" = Darwin ] && [ "$(/usr/bin/uname -m)" = arm64 ] &&
  [ "$(/usr/sbin/scutil --get LocalHostName)" = artemis ] || fail "Run this deployment on Artemis"

repo=$HOME/nix-config
checkout=$HOME/nix-config-deploy
state=$HOME/.local/state/nix-config/artemis
main=refs/remotes/origin/main
git=/usr/bin/git
nix_bin=/nix/var/nix/profiles/default/bin
profile=/nix/var/nix/profiles/system

mkdir -p "$state"
mkdir "$state/lock" || fail "Artemis deployment lock already exists: $state/lock"
trap 'rmdir "$state/lock"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

revision=${2:-}
if [ -z "$revision" ]; then
  "$git" -C "$repo" fetch --quiet origin "refs/heads/main:$main"
  revision=$("$git" -C "$repo" rev-parse --verify "$main^{commit}")
fi
case "$revision" in
  ''|*[!0-9a-f]*) fail "Invalid Artemis configuration commit" ;;
esac
[ "${#revision}" -eq 40 ] || fail "Expected a full Artemis configuration commit"
"$git" -C "$repo" merge-base --is-ancestor "$revision" "$main" || fail "Configuration commit is outside origin/main"

if [ -e "$checkout" ] || [ -L "$checkout" ]; then
  [ ! -L "$checkout" ] && [ -f "$checkout/.git" ] || fail "Unexpected deploy checkout: $checkout"
  repo_git_dir=$("$git" -C "$repo" rev-parse --path-format=absolute --git-common-dir)
  deploy_git_dir=$("$git" -C "$checkout" rev-parse --path-format=absolute --git-common-dir)
  [ "$repo_git_dir" = "$deploy_git_dir" ] || fail "Deploy checkout belongs to another repository: $checkout"
  changes=$("$git" --no-optional-locks -C "$checkout" status --porcelain=v1 --untracked-files=all)
  [ -z "$changes" ] || fail "Deploy checkout contains local changes: $checkout"
  "$git" -C "$checkout" switch --quiet --detach "$revision"
else
  "$git" -C "$repo" worktree add --quiet --detach "$checkout" "$revision"
fi
printf 'Artemis configuration checkout: %s (%s)\n' "$checkout" "$revision"
[ "$mode" != sync ] || exit 0

set -- build --no-update-lock-file --no-write-lock-file --out-link "$state/result" --print-out-paths
if [ "$mode" = debug ]; then
  set -- "$@" --show-trace --verbose
fi
previous=$(readlink /run/current-system)
previous_profile=$(readlink "$profile")
result=$("$nix_bin/nix" --extra-experimental-features 'nix-command flakes' "$@" \
  "git+file://$checkout?rev=$revision#darwinConfigurations.artemis.system" </dev/null)
[ "$result" = "$(readlink "$state/result")" ] || fail "Build did not return a single Darwin system"
[ "$(/usr/bin/plutil -extract configurationRevision raw -o - "$result/darwin-version.json")" = "$revision" ] ||
  fail "Built system does not match the selected configuration commit"
printf 'Artemis system built for %s: %s\n' "$revision" "$result"
[ "$mode" != build ] || exit 0

set -- -H
if [ ! -t 0 ]; then
  set -- "$@" -S -p ''
fi
/usr/bin/sudo "$@" /bin/sh -eu -c '
  profile=$1
  previous=$2
  previous_profile=$3
  result=$4
  if [ "$(readlink /run/current-system)" != "$previous" ] || [ "$(readlink "$profile")" != "$previous_profile" ]; then
    printf "Artemis changed during the build; rerun deployment against the current system\n" >&2
    exit 1
  fi
  # This is the profile registration followed by activation used by darwin-rebuild switch.
  /nix/var/nix/profiles/default/bin/nix-env --profile "$profile" --set "$result"
  "$result/sw/bin/darwin-rebuild" activate
  test "$(readlink /run/current-system)" = "$result"
  /usr/sbin/sshd -t
' deploy-artemis "$profile" "$previous" "$previous_profile" "$result"
printf 'Artemis deployed %s at %s\n' "$revision" "$(readlink "$profile")"
