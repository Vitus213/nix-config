#!/usr/bin/env bash
set -euo pipefail

if rg -n 'nixpkgs-stable|nixpkgs-2505|pkgs-stable|pkgs-2505|pkgs-master|nixpkgs-master' \
  flake.nix outputs lib hosts home modules hardening overlays secrets vars \
  --glob '*.nix'
then
  echo "Found stable/master Nixpkgs package-source references" >&2
  exit 1
fi
