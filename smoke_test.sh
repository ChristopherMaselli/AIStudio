#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/common.sh"

LEAVE_RUNNING=0
if [[ "${1:-}" == "--leave-running" ]]; then
  LEAVE_RUNNING=1
fi

studio_load_runtime_env

check_path() {
  local path="$1"
  [[ -e "$path" ]] || studio_die "Expected path is missing: $path"
}

studio_require_cmd git
studio_require_cmd python3
studio_require_cmd dotnet

check_path "$STUDIO_ROOT/apps/SwarmUI"
check_path "$STUDIO_ROOT/apps/ComfyUI"
check_path "$STUDIO_ROOT/env/comfyui"
check_path "$STUDIO_ROOT/config/studio.env"
check_path "$STUDIO_ROOT/config/swarmui.env"
check_path "$STUDIO_ROOT/config/comfyui.env"

started_comfy=0
started_swarm=0
comfy_probe_host="$(studio_probe_host "${STUDIO_COMFYUI_HOST:-127.0.0.1}")"
swarm_probe_host="$(studio_probe_host "${STUDIO_SWARMUI_HOST:-127.0.0.1}")"

if ! studio_is_pid_running "$(studio_service_pid comfyui)"; then
  bash "$SCRIPT_DIR/scripts/start_comfyui.sh"
  started_comfy=1
fi

if ! studio_http_ok "http://${comfy_probe_host}:${STUDIO_COMFYUI_PORT:-8188}/system_stats"; then
  studio_die "ComfyUI did not answer on /system_stats"
fi

if ! studio_is_pid_running "$(studio_service_pid swarmui)"; then
  bash "$SCRIPT_DIR/scripts/start_swarmui.sh"
  started_swarm=1
fi

if ! studio_http_ok "http://${swarm_probe_host}:${STUDIO_SWARMUI_PORT:-7801}/" && ! studio_http_ok "http://${swarm_probe_host}:${STUDIO_SWARMUI_PORT:-7801}/Install"; then
  studio_die "SwarmUI did not answer on / or /Install"
fi

if [[ "$LEAVE_RUNNING" -eq 0 ]]; then
  if [[ "$started_swarm" -eq 1 || "$started_comfy" -eq 1 ]]; then
    bash "$SCRIPT_DIR/scripts/stop_studio.sh"
  fi
fi

cat <<EOF
Smoke test passed.
  SwarmUI files: present
  ComfyUI files: present
  Venv: present
  ComfyUI HTTP: ok
  SwarmUI HTTP: ok
  Started by smoke test: comfyui=$started_comfy swarmui=$started_swarm
EOF
