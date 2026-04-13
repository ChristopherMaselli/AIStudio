#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

studio_load_runtime_env

for temp_dir in "$STUDIO_TMP_DIR" "$STUDIO_TMP_DIR/comfyui"; do
  if [[ -d "$temp_dir" ]]; then
    find "$temp_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    studio_log "Cleaned $temp_dir"
  fi
done

if [[ -d "$STUDIO_DATA_DIR/temp" ]]; then
  find "$STUDIO_DATA_DIR/temp" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  studio_log "Cleaned $STUDIO_DATA_DIR/temp"
fi
