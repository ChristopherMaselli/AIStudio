#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$SCRIPT_DIR"

# shellcheck disable=SC1091
source "$BOOTSTRAP_DIR/scripts/common.sh"

PURGE_SYSTEM_DEPS=0
ARCHIVE_DATA=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-system-deps)
      PURGE_SYSTEM_DEPS=1
      shift
      ;;
    --archive-data)
      ARCHIVE_DATA=1
      shift
      ;;
    *)
      studio_die "Unknown option: $1"
      ;;
  esac
done

studio_init_sudo

STUDIO_ROOT="${STUDIO_ROOT:-$HOME/ai-studio}"
if [[ -f "$STUDIO_ROOT/config/studio.env" ]]; then
  STUDIO_ENV_FILE="$STUDIO_ROOT/config/studio.env"
  studio_load_runtime_env
fi

MARKER_FILE="$STUDIO_ROOT/.ai-studio-bootstrap-owned"
MANIFEST_DIR="$BOOTSTRAP_DIR/manifest"
PACKAGES_MANIFEST="$MANIFEST_DIR/installed_packages.txt"
SYMLINKS_MANIFEST="$MANIFEST_DIR/created_symlinks.txt"
SERVICES_MANIFEST="$MANIFEST_DIR/created_services.txt"

removed_root="no"
removed_packages="no"
archive_path=""

if [[ -f "$STUDIO_ROOT/config/studio.env" ]]; then
  bash "$BOOTSTRAP_DIR/scripts/stop_studio.sh" >/dev/null 2>&1 || true
fi

if [[ "$ARCHIVE_DATA" -eq 1 && -d "$STUDIO_ROOT" ]]; then
  mkdir -p "$MANIFEST_DIR/backups"
  archive_path="$MANIFEST_DIR/backups/ai-studio-backup-$(date +%Y%m%d%H%M%S).tar.gz"
  tar -czf "$archive_path" -C "$STUDIO_ROOT" config data/outputs data/models 2>/dev/null || true
fi

if [[ -f "$SYMLINKS_MANIFEST" ]]; then
  while read -r link_path; do
    [[ -z "$link_path" || "$link_path" == \#* ]] && continue
    rm -f "$link_path"
  done <"$SYMLINKS_MANIFEST"
fi

if [[ -f "$SERVICES_MANIFEST" && -s "$SERVICES_MANIFEST" && -x "$(command -v systemctl || true)" ]]; then
  while read -r service_name; do
    [[ -z "$service_name" || "$service_name" == \#* ]] && continue
    "${STUDIO_SUDO[@]}" systemctl disable --now "$service_name" >/dev/null 2>&1 || true
    "${STUDIO_SUDO[@]}" rm -f "/etc/systemd/system/$service_name" >/dev/null 2>&1 || true
  done <"$SERVICES_MANIFEST"
fi

if [[ -d "$STUDIO_ROOT" ]]; then
  if [[ ! -f "$MARKER_FILE" ]]; then
    studio_die "Refusing to remove $STUDIO_ROOT because it is not marked as managed by ai-studio-bootstrap."
  fi
  rm -rf "$STUDIO_ROOT"
  removed_root="yes"
fi

if [[ "$PURGE_SYSTEM_DEPS" -eq 1 && -f "$PACKAGES_MANIFEST" ]]; then
  mapfile -t packages_to_remove < <(grep -v '^[[:space:]]*#' "$PACKAGES_MANIFEST" | sed '/^[[:space:]]*$/d')
  if [[ "${#packages_to_remove[@]}" -gt 0 ]]; then
    "${STUDIO_SUDO[@]}" apt-get remove -y "${packages_to_remove[@]}"
    "${STUDIO_SUDO[@]}" apt-get autoremove -y
    removed_packages="yes"
  fi
fi

cat <<EOF
Cleanup report:
  install root removed: $removed_root
  system packages purged: $removed_packages
  archive created: ${archive_path:-none}

Intentional leftovers:
  the bootstrap folder at $BOOTSTRAP_DIR
  manifest history in $MANIFEST_DIR

If you skipped --purge-system-deps, shared OS packages were left in place on purpose.
EOF
