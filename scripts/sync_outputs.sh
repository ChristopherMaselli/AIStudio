#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/common.sh"

studio_load_runtime_env
studio_require_cmd rsync

DESTINATION="${1:-${STUDIO_SYNC_DEST:-}}"
if [[ -z "$DESTINATION" ]]; then
  studio_die "Usage: bash scripts/sync_outputs.sh /path/to/destination"
fi

mkdir -p "$DESTINATION"

if [[ -d "$STUDIO_DATA_DIR/outputs" ]]; then
  rsync -a "$STUDIO_DATA_DIR/outputs/" "$DESTINATION/outputs/"
fi

if [[ -d "$STUDIO_ROOT/apps/SwarmUI/Data/Images" ]]; then
  rsync -a "$STUDIO_ROOT/apps/SwarmUI/Data/Images/" "$DESTINATION/swarmui-images/"
fi

studio_log "Outputs synced to $DESTINATION"
