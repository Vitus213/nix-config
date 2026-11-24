# just is a command runner, Justfile is very similar to Makefile, but simpler.

# Use nushell for shell commands
# To use this justfile, you need to enter a shell with just & nushell installed:
# 
#   nix shell nixpkgs#just nixpkgs#nushell
set shell := ["nu", "-c"]

utils_nu := absolute_path("utils.nu")

############################################################################
#
#  Common commands(suitable for all machines)
#
############################################################################

# List all the just commands
default:
    @just --list

# Run eval tests
[group('nix')]
test:
  bash scripts/check-nixpkgs-policy.sh
  nix eval .#evalTests --apply 'passed: assert passed; passed' --show-trace --print-build-logs --verbose

# Update all the flake inputs
[group('nix')]
up:
  nix flake update

# Update specific input
# Usage: just upp nixpkgs
[group('nix')]
upp input:
  nix flake update {{input}}

# List all generations of the system profile
[group('nix')]
history:
  nix profile history --profile /nix/var/nix/profiles/system

# Open a nix shell with the flake
[group('nix')]
repl:
  nix repl -f flake:nixpkgs

# remove all generations older than 7 days
# on darwin, you may need to switch to root user to run this command
[group('nix')]
clean:
  # Wipe out NixOS's history
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d
  # Wipe out home-manager's history
  nix profile wipe-history --profile $"($env.XDG_STATE_HOME)/nix/profiles/home-manager" --older-than 7d

# Garbage collect all unused nix store entries
[group('nix')]
gc:
  # garbage collect all unused nix store entries(system-wide)
  sudo nix-collect-garbage --delete-older-than 7d
  # garbage collect all unused nix store entries(for the user - home-manager)
  # https://github.com/NixOS/nix/issues/8508
  nix-collect-garbage --delete-older-than 7d

# Enter a shell session which has all the necessary tools for this flake
[linux]
[group('nix')]
shell:
  nix shell nixpkgs#git nixpkgs#neovim

# Enter a shell session which has all the necessary tools for this flake
[macos]
[group('nix')]
shell:
  nix shell nixpkgs#git nixpkgs#neovim

[group('nix')]
fmt:
  # format the nix files in this repo
  ls **/*.nix | each { |it| nixfmt $it.name }

# Show all the auto gc roots in the nix store
[group('nix')]
gcroot:
  ls -al /nix/var/nix/gcroots/auto/

# Verify all the store entries
# Nix Store can contains corrupted entries if the nix store object has been modified unexpectedly.
# This command will verify all the store entries,
# and we need to fix the corrupted entries manually via `sudo nix store delete <store-path-1> <store-path-2> ...`
[group('nix')]
verify-store:
  nix store verify --all

# Repair Nix Store Objects
[group('nix')]
repair-store *paths:
  nix store repair {{paths}}

# Update all Nixpkgs inputs
[group('nix')]
up-nix:
  nix flake update nixpkgs nixpkgs-darwin

# override nixpkgs's commit hash
[group('nix')]
override-pkgs hash:
  nix flake update nixpkgs --override-input nixpkgs github:NixOS/nixpkgs/{{hash}}

############################################################################
#
#  NixOS Desktop related commands
#
############################################################################

# Deploy the nixosConfiguration by hostname match
[linux]
[group('homelab')]
local mode="default":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  local-switch (current-local-host) {{mode}}

# Sync a deployment worktree on the target and rebuild there.
# 前提（目标机，见 hosts/olympians-athena/default.nix）：vitus 对
# /nix/store/*/bin/nixos-rebuild switch 免密。首次需手动跑一次带密码的
# sudo nixos-rebuild switch 装上该规则。
[linux]
[group('homelab')]
remote-host host mode="switch":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ {{quote(host)}} == artemis ]]; then
      mode={{quote(mode)}}
      case "$mode" in
        sync|build) terminal=(-T) ;;
        switch|debug) terminal=(-t) ;;
        *) echo 'Artemis mode must be sync, build, switch, or debug' >&2; exit 1 ;;
      esac
      exec ssh "${terminal[@]}" -o BatchMode=yes artemis '
        set -eu
        umask 077
        repo=$HOME/nix-config
        main=refs/remotes/origin/main
        /usr/bin/git -C "$repo" fetch --quiet origin "refs/heads/main:$main"
        revision=$(/usr/bin/git -C "$repo" rev-parse --verify "$main^{commit}")
        driver=$(/usr/bin/mktemp /tmp/deploy-artemis.XXXXXXXX)
        trap "rm -f \"\$driver\"" EXIT
        /usr/bin/git -C "$repo" show "$revision:scripts/deploy-artemis.sh" >"$driver"
        /usr/bin/caffeinate -is /bin/sh "$driver" '"$mode"' "$revision"
      '
    fi
    remote="vitus@{{host}}"
    ssh -o BatchMode=yes "$remote" '
      set -e
      cd ~/nix-config && git fetch origin main -q
      git -C /tmp/nixcfg-deploy checkout --detach -q origin/main 2>/dev/null ||
        git -C ~/nix-config worktree add -q /tmp/nixcfg-deploy origin/main
    '
    if ! ssh -o BatchMode=yes "$remote" \
        "sudo -n nixos-rebuild {{mode}} --flake /tmp/nixcfg-deploy#{{host}}"; then
      echo "sudo 免密不可用：请在 {{host}} 上手动执行一次" \
        "sudo nixos-rebuild switch --flake /tmp/nixcfg-deploy#{{host}}" >&2
      exit 1
    fi

############################################################################
#
#  Darwin related commands
#
############################################################################

[macos]
[group('desktop')]
darwin-rollback:
  sudo -H /run/current-system/sw/bin/darwin-rebuild --rollback

# Deploy Artemis from origin/main.
[macos]
[group('desktop')]
local mode="default":
  /usr/bin/caffeinate -is /bin/sh scripts/deploy-artemis.sh {{quote(mode)}}

# Deploy Artemis when the host is provided explicitly.
[macos]
[group('desktop')]
local-host host mode="default":
  #!/bin/sh
  if [ {{quote(host)}} != artemis ]; then
    printf 'The Darwin configuration is artemis\n' >&2
    exit 1
  fi
  exec /usr/bin/caffeinate -is /bin/sh scripts/deploy-artemis.sh {{quote(mode)}}


# Reset launchpad to force it to reindex Applications
[macos]
[group('desktop')]
reset-launchpad:
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock

# =================================================
#
# Other useful commands
#
# =================================================

[group('common')]
path:
   $env.PATH | split row ":"

[group('common')]
trace-access app *args:
  strace -f -t -e trace=file {{app}} {{args}} | complete | $in.stderr | lines | find -v -r "(/nix/store|/newroot|/proc)" | parse --regex '"(/.+)"' | sort | uniq

[linux]
[group('common')]
penvof pid:
  sudo cat $"/proc/($pid)/environ" | tr '\0' '\n'

# Remove all reflog entries and prune unreachable objects
[group('git')]
ggc:
  git reflog expire --expire-unreachable=now --all
  git gc --prune=now

# Amend the last commit without changing the commit message
[group('git')]
game:
  git commit --amend -a --no-edit


[linux]
[group('services')]
list-inactive:
  systemctl list-units -all --state=inactive

[linux]
[group('services')]
list-failed:
  systemctl list-units -all --state=failed

[linux]
[group('services')]
list-systemd:
  systemctl list-units systemd-*

[linux]
[group('github')]
gh-login:
  gh auth login -h github.com --skip-ssh-key --git-protocol https --web
