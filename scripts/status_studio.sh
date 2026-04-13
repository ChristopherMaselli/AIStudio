#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

studio_load_runtime_env

status_line() {
  local name="$1"
  local pid
  pid="$(studio_service_pid "$name")"
  if studio_is_pid_running "$pid"; then
    printf '%s: running (PID %s)\n' "$name" "$pid"
  else
    printf '%s: stopped\n' "$name"
  fi
}

printf 'Install root: %s\n' "$STUDIO_ROOT"
printf 'Mode: %s\n' "${STUDIO_MODE:-unknown}"
printf 'SwarmUI URL: http://%s:%s\n' "$(studio_probe_host "${STUDIO_SWARMUI_HOST:-127.0.0.1}")" "${STUDIO_SWARMUI_PORT:-7801}"
printf 'ComfyUI URL: http://%s:%s\n' "$(studio_probe_host "${STUDIO_COMFYUI_HOST:-127.0.0.1}")" "${STUDIO_COMFYUI_PORT:-8188}"
status_line swarmui
status_line comfyui

if studio_http_ok "http://$(studio_probe_host "${STUDIO_SWARMUI_HOST:-127.0.0.1}"):${STUDIO_SWARMUI_PORT:-7801}/" || studio_http_ok "http://$(studio_probe_host "${STUDIO_SWARMUI_HOST:-127.0.0.1}"):${STUDIO_SWARMUI_PORT:-7801}/Install"; then
  printf 'SwarmUI HTTP: reachable\n'
else
  printf 'SwarmUI HTTP: unreachable\n'
fi

if studio_http_ok "http://$(studio_probe_host "${STUDIO_COMFYUI_HOST:-127.0.0.1}"):${STUDIO_COMFYUI_PORT:-8188}/system_stats"; then
  printf 'ComfyUI HTTP: reachable\n'
else
  printf 'ComfyUI HTTP: unreachable\n'
fi
