#!/usr/bin/env bash

set -euo pipefail

TOTP_CONFIG_FILE="$HOME/.config/totp/secrets.conf"
TOTP_CURRENT_INDEX_FILE="$HOME/.config/totp/current_index"

init_totp_config() {
  local config_dir
  config_dir="$(dirname "$TOTP_CONFIG_FILE")"
  mkdir -p "$config_dir"
  chmod 700 "$config_dir"

  if [[ ! -f "$TOTP_CONFIG_FILE" ]]; then
    cat > "$TOTP_CONFIG_FILE" << 'EOC'
# TOTP key configuration file
# Format: service_name:key
# Example:
# Google:JBSWY3DPEHPK3PXP
# GitHub:ABCDEFGHIJKLMNOP
# Please replace with your actual keys
EOC
    chmod 600 "$TOTP_CONFIG_FILE"
    return 1
  fi
  return 0
}

validate_totp_config() {
  if [[ ! -f "$TOTP_CONFIG_FILE" ]] || [[ ! -s "$TOTP_CONFIG_FILE" ]]; then
    return 1
  fi

  local services
  services=$(grep -v '^#' "$TOTP_CONFIG_FILE" | grep ':' || true)
  [[ -n "$services" ]]
}

get_totp_services() {
  if ! validate_totp_config; then
    return 1
  fi

  grep -v '^#' "$TOTP_CONFIG_FILE" | grep ':'
}

get_current_index() {
  local current_index=1

  if [[ -f "$TOTP_CURRENT_INDEX_FILE" ]]; then
    current_index=$(cat "$TOTP_CURRENT_INDEX_FILE" 2>/dev/null || echo 1)
  fi

  local total_services
  total_services=$(get_totp_services | wc -l)
  if [[ "$current_index" -gt "$total_services" ]] || [[ "$current_index" -lt 1 ]]; then
    current_index=1
    echo "$current_index" > "$TOTP_CURRENT_INDEX_FILE"
  fi

  echo "$current_index"
}

set_current_index() {
  local index="$1"
  local total_services
  total_services=$(get_totp_services | wc -l)

  if [[ "$index" -gt "$total_services" ]] || [[ "$index" -lt 1 ]]; then
    return 1
  fi

  echo "$index" > "$TOTP_CURRENT_INDEX_FILE"
  return 0
}

get_service_info() {
  local index="$1"
  local services
  services=$(get_totp_services)

  if [[ -z "$services" ]]; then
    return 1
  fi

  local service_line
  service_line=$(echo "$services" | sed -n "${index}p")
  if [[ -z "$service_line" ]]; then
    return 1
  fi

  local service_name secret_key
  service_name=$(echo "$service_line" | cut -d':' -f1)
  secret_key=$(echo "$service_line" | cut -d':' -f2)

  if ! validate_totp_key "$secret_key"; then
    return 1
  fi

  echo "$service_name:$secret_key"
}

validate_totp_key() {
  local key="$1"
  [[ "$key" =~ ^[A-Z2-7]+=*$ ]] && [[ ${#key} -ge 16 ]]
}

generate_totp_code() {
  local secret_key="$1"

  if ! command -v oathtool >/dev/null 2>&1; then
    return 2
  fi

  if ! validate_totp_key "$secret_key"; then
    return 3
  fi

  local totp_code
  totp_code=$(oathtool --totp -b "$secret_key" 2>/dev/null || true)
  if [[ -n "$totp_code" ]]; then
    echo "$totp_code"
    return 0
  fi

  return 1
}

get_totp_remaining_time() {
  local current_time
  current_time=$(date +%s)
  echo $((30 - (current_time % 30)))
}

get_totp_color() {
  local remaining="$1"
  if [[ "$remaining" -le 5 ]]; then
    echo "error"
  elif [[ "$remaining" -le 10 ]]; then
    echo "tertiary"
  else
    echo "primary"
  fi
}

generate_services_list() {
  local current_index="$1"
  local services
  services=$(get_totp_services)
  local services_list=""
  local i=1

  while IFS= read -r line; do
    local svc_name
    svc_name=$(echo "$line" | cut -d':' -f1)
    if [[ "$i" -eq "$current_index" ]]; then
      services_list+="▶ ${svc_name} (current)\\n"
    else
      services_list+="  ${svc_name}\\n"
    fi
    i=$((i + 1))
  done <<< "$services"

  echo "$services_list"
}

switch_to_next_service() {
  local current_index total_services next_index
  current_index=$(get_current_index)
  total_services=$(get_totp_services | wc -l)
  next_index=$((current_index + 1))

  if [[ "$next_index" -gt "$total_services" ]]; then
    next_index=1
  fi

  set_current_index "$next_index"
  echo "$next_index"
}

json_escape() {
  local s="$1"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  s=${s//$'\t'/\\t}
  echo "$s"
}
