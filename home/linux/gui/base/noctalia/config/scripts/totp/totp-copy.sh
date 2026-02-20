#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/totp-common.sh"

if ! validate_totp_config; then
  notify-send "TOTP" "配置文件不存在或为空：~/.config/totp/secrets.conf" -u critical
  exit 1
fi

current_index=$(get_current_index)
service_info=$(get_service_info "$current_index" || true)
if [[ -z "$service_info" ]]; then
  notify-send "TOTP" "当前服务配置无效" -u critical
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
notify-send "TOTP" "${service_name}: ${totp_code}\\n剩余: ${remaining}s\\n已复制到剪贴板" -t 3500
