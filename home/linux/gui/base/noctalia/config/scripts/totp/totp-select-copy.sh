#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/totp-common.sh"

if ! validate_totp_config; then
  notify-send "TOTP" "配置文件不存在或为空：~/.config/totp/secrets.conf" -u critical
  exit 1
fi

menu_entries=$(list_totp_services_with_index || true)
if [[ -z "$menu_entries" ]]; then
  notify-send "TOTP" "没有可用服务" -u critical
  exit 1
fi

selected=""
if ! selected=$(pick_from_menu "TOTP" "$menu_entries"); then
  rc=$?
  if [[ "$rc" -eq 127 ]]; then
    notify-send "TOTP" "未找到菜单程序，请安装 fuzzel/wofi/rofi/bemenu 之一" -u critical
    exit 1
  fi
  exit 0
fi

if [[ -z "${selected:-}" ]]; then
  exit 0
fi

IFS=$'\t' read -r selected_index _ <<< "$selected"
if [[ ! "$selected_index" =~ ^[0-9]+$ ]]; then
  notify-send "TOTP" "无效选择：${selected}" -u critical
  exit 1
fi

if ! set_current_index "$selected_index"; then
  notify-send "TOTP" "无法切换到第 ${selected_index} 项" -u critical
  exit 1
fi

service_info=$(get_service_info "$selected_index" || true)
if [[ -z "$service_info" ]]; then
  notify-send "TOTP" "选中服务配置无效" -u critical
  exit 1
fi

service_name=$(echo "$service_info" | cut -d':' -f1)
secret_key=$(echo "$service_info" | cut -d':' -f2)

totp_code=$(generate_totp_code "$secret_key" || true)
status=$?
case "$status" in
  0)
    ;;
  2)
    notify-send "TOTP" "缺少 oathtool，请安装 oath-toolkit" -u critical
    exit 1
    ;;
  3)
    notify-send "TOTP" "${service_name} 的密钥格式无效" -u critical
    exit 1
    ;;
  *)
    notify-send "TOTP" "生成验证码失败：${service_name}" -u critical
    exit 1
    ;;
esac

echo -n "$totp_code" | wl-copy
remaining=$(get_totp_remaining_time)
notify-send "TOTP" "已选择: ${service_name}\\n验证码: ${totp_code}\\n剩余: ${remaining}s\\n已复制到剪贴板" -t 3500
