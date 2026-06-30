#!/usr/bin/env bash
set -euo pipefail

workspace_order=(
  "1terminal:1"
  "2browser:2"
  "3docs:3"
  "4codex:4"
  "5code:5"
  "6chat:6"
  "8music:8"
  "9file:9"
  "0other:10"
)

for item in "${workspace_order[@]}"; do
  name="${item%%:*}"
  index="${item##*:}"
  niri msg action move-workspace-to-index --reference "$name" "$index" >/dev/null 2>&1 || true
done
