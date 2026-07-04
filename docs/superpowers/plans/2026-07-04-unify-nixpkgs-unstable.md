# Unify Nixpkgs Unstable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move direct package sources away from stable/master-specific Nixpkgs inputs and make
normal Linux packages use the main unstable package set.

**Architecture:** Keep the main `nixpkgs` input on `nixos-unstable` and Darwin on
`nixpkgs-unstable`. Remove `pkgs-stable`, `pkgs-2505`, and `pkgs-master` special package sets from
module arguments, replacing their package references with `pkgs` where possible.

**Tech Stack:** Nix flakes, NixOS, nix-darwin, Home Manager, shell-based static checks, `just test`.

---

### Task 1: Add Policy Check

**Files:**

- Create: `scripts/check-nixpkgs-policy.sh`

- [ ] **Step 1: Write the failing check**

```bash
#!/usr/bin/env bash
set -euo pipefail

if rg -n 'nixpkgs-stable|nixpkgs-2505|pkgs-stable|pkgs-2505|pkgs-master|nixpkgs-master' \
  flake.nix outputs home modules hardening documents --glob '*.nix' --glob '*.md'
then
  echo "Found stable/master Nixpkgs package-source references" >&2
  exit 1
fi
```

- [ ] **Step 2: Run check and verify it fails**

Run: `bash scripts/check-nixpkgs-policy.sh`

Expected: FAIL, listing current `pkgs-stable`, `pkgs-2505`, `pkgs-master`, and `nixpkgs-master`
references.

### Task 2: Replace Package-Source Inputs

**Files:**

- Modify: `flake.nix`
- Modify: `outputs/default.nix`
- Modify: `home/linux/gui/base/editors.nix`
- Modify: `home/base/tui/editors/packages.nix`
- Modify: `modules/nixos/desktop/networking/clash-verge.nix`
- Modify: `modules/nixos/desktop/guix.nix`
- Modify: `hardening/nixpaks/default.nix`

- [ ] **Step 1: Remove direct stable/master inputs from `flake.nix`**

Remove `nixpkgs-stable`, `nixpkgs-2505`, and `nixpkgs-master` inputs.

- [ ] **Step 2: Remove imported special package sets**

Delete `pkgs-2505`, `pkgs-stable`, and `pkgs-master` from `outputs/default.nix`.

- [ ] **Step 3: Use `pkgs` in modules**

Replace module arguments and package references:

```nix
pkgs-master.code-cursor -> pkgs.code-cursor
pkgs-master.vscode -> pkgs.vscode
pkgs-stable.wpsoffice-cn -> pkgs.wpsoffice-cn
pkgs-master.rustc -> pkgs.rustc
pkgs-master.rust-analyzer -> pkgs.rust-analyzer
pkgs-master.cargo -> pkgs.cargo
pkgs-master.rustfmt -> pkgs.rustfmt
pkgs-master.clippy -> pkgs.clippy
pkgs-master.clash-verge-rev -> pkgs.clash-verge-rev
pkgs-master.guix -> pkgs.guix
pkgs-master.qq -> pkgs.qq
pkgs-master.fetchurl -> pkgs.fetchurl
pkgs-master.callPackage -> pkgs.callPackage
```

### Task 3: Update Documentation

**Files:**

- Modify: `documents/application-version-audit.md`
- Modify: `documents/linux-im-apps.md`
- Modify: `documents/changelog.md`

- [ ] **Step 1: Update package source descriptions**

Document that WPS, Cursor, VSCode, Clash Verge, Guix, Rust tooling, and QQ now resolve through the
main unstable `pkgs` package set unless they are locally pinned.

- [ ] **Step 2: Add changelog entry**

Add a 2026-07-04 entry that lists scope, config entry points, validation commands, and links to
`application-version-audit.md`.

### Task 4: Update Lock And Verify

**Files:**

- Modify: `flake.lock`

- [ ] **Step 1: Update lock file**

Run: `nix flake update`

- [ ] **Step 2: Verify policy check**

Run: `bash scripts/check-nixpkgs-policy.sh`

Expected: PASS.

- [ ] **Step 3: Verify evaluation**

Run: `just test`

Expected: PASS.

- [ ] **Step 4: Verify key package availability**

Run:

```bash
nix eval --raw .#nixosConfigurations.apollo.pkgs.bun.version
nix eval --raw .#nixosConfigurations.apollo.pkgs.vscode.version
nix eval --raw .#nixosConfigurations.apollo.pkgs.clash-verge-rev.version
```

Expected: commands evaluate or identify packages that must be handled explicitly.
