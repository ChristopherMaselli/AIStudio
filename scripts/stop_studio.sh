#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

studio_load_runtime_env

stop_service() {
  local name="$1"
  local pid_file
  local pid
  pid_file="$(studio_pid_file "$name")"
  pid="$(studio_service_pid "$name")"

  if studio_is_pid_running "$pid"; then
    studio_log "Stopping $name (PID $pid)"
    kill "$pid" >/dev/null 2>&1 || true
    for _ in $(seq 1 20); do
      if ! studio_is_pid_running "$pid"; then
        break
      fi
      sleep 1
    done
    if studio_is_pid_running "$pid"; then
      studio_warn "$name did not stop cleanly; sending SIGKILL."
      kill -9 "$pid" >/dev/null 2>&1 || true
    fi
  fi

  rm -f "$pid_file"
}

stop_service swarmui
stop_service comfyui

if command -v pkill >/dev/null 2>&1; then
  pkill -f "$STUDIO_ROOT/apps/ComfyUI/main.py" >/dev/null 2>&1 || true
  pkill -f "$STUDIO_ROOT/apps/SwarmUI/src/bin/live_release/SwarmUI" >/dev/null 2>&1 || true
fi

studio_log "Studio processes stopped."
