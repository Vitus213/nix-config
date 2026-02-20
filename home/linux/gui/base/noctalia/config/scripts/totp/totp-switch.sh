#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/totp-common.sh"

if ! validate_totp_config; then
  notify-send "TOTP" "配置文件不存在或为空：~/.config/totp/secrets.conf" -u critical
  exit 1
fi

next_index=$(switch_to_next_service || true)
if [[ -z "$next_index" ]]; then
  notify-send "TOTP" "切换服务失败" -u critical
  exit 1
fi

service_info=$(get_service_info "$next_index" || true)
if [[ -z "$service_info" ]]; then
  notify-send "TOTP" "切换后服务配置无效" -u critical
  exit 1
fi

service_name=$(echo "$service_info" | cut -d':' -f1)
secret_key=$(echo "$service_info" | cut -d':' -f2)

totp_code=$(generate_totp_code "$secret_key" || true)
status=$?
case "$status" in
  0)
    remaining=$(get_totp_remaining_time)
    notify-send "TOTP" "已切换到: ${service_name}\\n验证码: ${totp_code}\\n剩余: ${remaining}s" -t 3000
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
    notify-send "TOTP" "切换成功，但验证码生成失败：${service_name}" -u normal
    ;;
esac
