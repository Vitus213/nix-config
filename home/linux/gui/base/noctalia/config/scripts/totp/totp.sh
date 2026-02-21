#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/totp-common.sh"

emit() {
  local text="$1" icon="$2" tooltip="$3" color="$4"
  printf '{"text":"%s","icon":"%s","tooltip":"%s","color":"%s"}\n' \
    "$(json_escape "$text")" "$(json_escape "$icon")" "$(json_escape "$tooltip")" "$(json_escape "$color")"
}

if ! init_totp_config; then
  emit "TOTP 未配置" "lock" "请编辑 ~/.config/totp/secrets.conf 添加密钥" "error"
  exit 0
fi

if ! validate_totp_config; then
  emit "TOTP 无可用项" "lock" "配置为空或格式错误：~/.config/totp/secrets.conf" "error"
  exit 0
fi

current_index=$(get_current_index)
service_info=$(get_service_info "$current_index" || true)
if [[ -z "$service_info" ]]; then
  emit "TOTP 配置错误" "lock" "当前服务索引无效或密钥格式不正确" "error"
  exit 0
fi

service_name=$(echo "$service_info" | cut -d':' -f1)
secret_key=$(echo "$service_info" | cut -d':' -f2)

totp_code=$(generate_totp_code "$secret_key" || true)
status=$?
if [[ "$status" -eq 2 ]]; then
  emit "缺少 oathtool" "lock" "请安装 oath-toolkit (oathtool)" "error"
  exit 0
elif [[ "$status" -eq 3 ]]; then
  emit "密钥格式错误" "lock" "$service_name 的密钥不是有效 Base32" "error"
  exit 0
elif [[ -z "$totp_code" ]]; then
  emit "TOTP 生成失败" "lock" "无法为 $service_name 生成验证码" "error"
  exit 0
fi

remaining=$(get_totp_remaining_time)
color=$(get_totp_color "$remaining")
total_services=$(get_totp_services | wc -l)
services_list=$(generate_services_list "$current_index")

tooltip="${service_name} TOTP: ${totp_code}\\n剩余: ${remaining} 秒\\n\\n可用服务 (${current_index}/${total_services}):\\n${services_list}\\n左键: 复制验证码\\n中键: 列表选择并复制\\n右键: 切换服务"
emit "${service_name} ${totp_code}" "lock" "$tooltip" "$color"
