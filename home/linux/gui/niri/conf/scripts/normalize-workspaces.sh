#!/usr/bin/env bash
set -euo pipefail

# 从大 index 往小移才会收敛：先固定 0other:10，再依次归位 9/8/7…，
# 正序移动会把后面的工作区反复挤离目标位。
workspace_order=(
  "0other:10"
  "9file:9"
  "8music:8"
  "7misc:7"
  "6chat:6"
  "5code:5"
  "4codex:4"
  "3docs:3"
  "2browser:2"
  "1terminal:1"
)

for item in "${workspace_order[@]}"; do
  name="${item%%:*}"
  index="${item##*:}"
  niri msg action move-workspace-to-index --reference "$name" "$index" >/dev/null 2>&1 || true
done
