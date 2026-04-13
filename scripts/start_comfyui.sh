#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

studio_load_runtime_env

COMFY_DIR="$STUDIO_ROOT/apps/ComfyUI"
VENV_DIR="$STUDIO_ROOT/env/comfyui"
LOG_FILE="$STUDIO_LOG_DIR/comfyui.log"
PID_FILE="$(studio_pid_file comfyui)"
HOST="${STUDIO_COMFYUI_HOST:-127.0.0.1}"
PORT="${STUDIO_COMFYUI_PORT:-8188}"
PROBE_HOST="$(studio_probe_host "$HOST")"

mkdir -p "$STUDIO_LOG_DIR" "$STUDIO_TMP_DIR" "$STUDIO_DATA_DIR/inputs" "$STUDIO_DATA_DIR/outputs/comfyui" "$STUDIO_TMP_DIR/comfyui" "$STUDIO_DATA_DIR/comfyui-user"

if [[ ! -d "$COMFY_DIR" ]]; then
  studio_die "ComfyUI is not installed at $COMFY_DIR"
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  studio_die "ComfyUI venv missing at $VENV_DIR"
fi

mkdir -p "$COMFY_DIR/custom_nodes"
if [[ -L "$STUDIO_DATA_DIR/custom_nodes" ]]; then
  :
elif [[ -e "$STUDIO_DATA_DIR/custom_nodes" ]]; then
  studio_warn "$STUDIO_DATA_DIR/custom_nodes already exists and is not a symlink; leaving it in place."
else
  ln -s "$COMFY_DIR/custom_nodes" "$STUDIO_DATA_DIR/custom_nodes"
fi

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(studio_service_pid comfyui)"
  if studio_is_pid_running "$existing_pid"; then
    studio_log "ComfyUI is already running with PID $existing_pid"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

extra_args=()
if [[ -n "${STUDIO_COMFYUI_ARGS:-}" ]]; then
  read -r -a extra_args <<< "$STUDIO_COMFYUI_ARGS"
fi

cmd=(
  "$VENV_DIR/bin/python"
  "$COMFY_DIR/main.py"
  --listen "$HOST"
  --port "$PORT"
  --base-directory "$STUDIO_DATA_DIR"
  --output-directory "$STUDIO_DATA_DIR/outputs/comfyui"
  --input-directory "$STUDIO_DATA_DIR/inputs"
  --temp-directory "$STUDIO_TMP_DIR/comfyui"
  --user-directory "$STUDIO_DATA_DIR/comfyui-user"
  --disable-auto-launch
)

if [[ "${STUDIO_COMFYUI_ENABLE_MANAGER:-1}" == "1" ]]; then
  cmd+=(--enable-manager)
fi

device_mode="${STUDIO_COMFYUI_DEVICE_MODE:-auto}"
if [[ "$device_mode" == "cpu" ]] || { [[ "$device_mode" == "auto" ]] && ! studio_nvidia_available; }; then
  cmd+=(--cpu)
fi

if [[ -n "${STUDIO_COMFYUI_CUDA_DEVICE:-}" ]]; then
  cmd+=(--cuda-device "$STUDIO_COMFYUI_CUDA_DEVICE")
fi

if [[ ${#extra_args[@]} -gt 0 ]]; then
  cmd+=("${extra_args[@]}")
fi

(
  cd "$COMFY_DIR"
  nohup "${cmd[@]}" >>"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
)

if studio_wait_for_http "http://${PROBE_HOST}:${PORT}/system_stats" 180; then
  studio_log "ComfyUI is up at http://${PROBE_HOST}:${PORT}"
else
  rm -f "$PID_FILE"
  studio_tail_log_hint "$LOG_FILE"
  studio_die "ComfyUI did not become ready in time."
fi
