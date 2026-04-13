#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

studio_load_runtime_env

SWARM_DIR="$STUDIO_ROOT/apps/SwarmUI"
LOG_FILE="$STUDIO_LOG_DIR/swarmui.log"
PID_FILE="$(studio_pid_file swarmui)"
HOST="${STUDIO_SWARMUI_HOST:-127.0.0.1}"
PORT="${STUDIO_SWARMUI_PORT:-7801}"
PROBE_HOST="$(studio_probe_host "$HOST")"

mkdir -p "$STUDIO_LOG_DIR" "$STUDIO_TMP_DIR"

if [[ ! -d "$SWARM_DIR" ]]; then
  studio_die "SwarmUI is not installed at $SWARM_DIR"
fi

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(studio_service_pid swarmui)"
  if studio_is_pid_running "$existing_pid"; then
    studio_log "SwarmUI is already running with PID $existing_pid"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

extra_args=()
if [[ -n "${STUDIO_SWARMUI_ARGS:-}" ]]; then
  read -r -a extra_args <<< "$STUDIO_SWARMUI_ARGS"
fi

cmd=(
  ./launch-linux.sh
  --launch_mode none
  --host "$HOST"
  --port "$PORT"
)

if [[ ${#extra_args[@]} -gt 0 ]]; then
  cmd+=("${extra_args[@]}")
fi

(
  cd "$SWARM_DIR"
  nohup env ASPNETCORE_URLS="http://${HOST}:${PORT}" "${cmd[@]}" >>"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
)

if studio_wait_for_http "http://${PROBE_HOST}:${PORT}/" 240 || studio_wait_for_http "http://${PROBE_HOST}:${PORT}/Install" 240; then
  studio_log "SwarmUI is up at http://${PROBE_HOST}:${PORT}"
else
  rm -f "$PID_FILE"
  studio_tail_log_hint "$LOG_FILE"
  studio_die "SwarmUI did not become ready in time."
fi
