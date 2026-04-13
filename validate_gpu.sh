#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/scripts/common.sh"

studio_load_runtime_env
studio_require_cmd nvidia-smi

if ! nvidia-smi -L >/dev/null 2>&1; then
  studio_die "No NVIDIA GPU was detected by nvidia-smi."
fi

export STUDIO_COMFYUI_DEVICE_MODE="auto"

printf 'nvidia-smi summary:\n'
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader

python_report="$("$STUDIO_ROOT/env/comfyui/bin/python" - <<'PY'
import torch
print(f"torch_cuda_available={torch.cuda.is_available()}")
print(f"torch_cuda_device_count={torch.cuda.device_count()}")
if torch.cuda.is_available() and torch.cuda.device_count() > 0:
    print(f"torch_cuda_device_0={torch.cuda.get_device_name(0)}")
PY
)"

printf '%s\n' "$python_report"
if ! grep -q 'torch_cuda_available=True' <<<"$python_report"; then
  studio_die "PyTorch in the ComfyUI venv does not currently see a CUDA device."
fi

started_comfy=0
started_swarm=0
comfy_probe_host="$(studio_probe_host "${STUDIO_COMFYUI_HOST:-127.0.0.1}")"
swarm_probe_host="$(studio_probe_host "${STUDIO_SWARMUI_HOST:-127.0.0.1}")"

if ! studio_is_pid_running "$(studio_service_pid comfyui)"; then
  bash "$SCRIPT_DIR/scripts/start_comfyui.sh"
  started_comfy=1
fi

if ! studio_http_ok "http://${comfy_probe_host}:${STUDIO_COMFYUI_PORT:-8188}/system_stats"; then
  studio_die "ComfyUI failed HTTP validation on this GPU host."
fi

if ! studio_is_pid_running "$(studio_service_pid swarmui)"; then
  bash "$SCRIPT_DIR/scripts/start_swarmui.sh"
  started_swarm=1
fi

if ! studio_http_ok "http://${swarm_probe_host}:${STUDIO_SWARMUI_PORT:-7801}/" && ! studio_http_ok "http://${swarm_probe_host}:${STUDIO_SWARMUI_PORT:-7801}/Install"; then
  studio_die "SwarmUI failed HTTP validation on this GPU host."
fi

if [[ "$started_swarm" -eq 1 || "$started_comfy" -eq 1 ]]; then
  bash "$SCRIPT_DIR/scripts/stop_studio.sh"
fi

cat <<EOF
GPU validation passed.
  nvidia-smi: ok
  torch cuda visibility: ok
  ComfyUI HTTP: ok
  SwarmUI HTTP: ok
EOF
