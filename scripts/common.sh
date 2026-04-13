#!/usr/bin/env bash

studio_default_bootstrap_dir() {
  local source_path="${BASH_SOURCE[0]}"
  local source_dir
  source_dir="$(cd "$(dirname "$source_path")" && pwd)"
  if [[ "$(basename "$source_dir")" == "scripts" ]]; then
    (cd "$source_dir/.." && pwd)
  else
    printf '%s\n' "$source_dir"
  fi
}

studio_log() {
  printf '[studio] %s\n' "$*"
}

studio_warn() {
  printf '[studio][warn] %s\n' "$*" >&2
}

studio_die() {
  printf '[studio][error] %s\n' "$*" >&2
  exit 1
}

studio_require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    studio_die "Missing required command: $1"
  fi
}

studio_init_sudo() {
  STUDIO_SUDO=()
  if [[ "$(id -u)" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      STUDIO_SUDO=(sudo)
    else
      studio_die "This action needs root privileges and sudo is not available."
    fi
  fi
}

studio_probe_host() {
  case "${1:-127.0.0.1}" in
    0.0.0.0|localhost|'*'|'::'|'[::]'|'0:0:0:0:0:0:0:0')
      printf '%s\n' "127.0.0.1"
      ;;
    *)
      printf '%s\n' "${1:-127.0.0.1}"
      ;;
  esac
}

studio_http_get() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  else
    wget -qO- "$url"
  fi
}

studio_http_ok() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS -o /dev/null "$url" >/dev/null 2>&1
  else
    wget -q --spider "$url" >/dev/null 2>&1
  fi
}

studio_wait_for_http() {
  local url="$1"
  local timeout="${2:-120}"
  local attempt
  for attempt in $(seq 1 "$timeout"); do
    if studio_http_ok "$url"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

studio_pid_file() {
  printf '%s\n' "${STUDIO_TMP_DIR:-$HOME/ai-studio/tmp}/$1.pid"
}

studio_is_pid_running() {
  local pid="$1"
  [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1
}

studio_service_pid() {
  local pid_file
  pid_file="$(studio_pid_file "$1")"
  if [[ -f "$pid_file" ]]; then
    tr -d '[:space:]' < "$pid_file"
  fi
}

studio_load_runtime_env() {
  local default_root="${STUDIO_ROOT:-$HOME/ai-studio}"
  local studio_env_file="$default_root/config/studio.env"

  if [[ -n "${STUDIO_ENV_FILE:-}" ]]; then
    studio_env_file="$STUDIO_ENV_FILE"
  fi

  if [[ ! -f "$studio_env_file" ]]; then
    studio_die "Studio config not found at $studio_env_file. Run bash install.sh first."
  fi

  # shellcheck disable=SC1090
  source "$studio_env_file"
  # shellcheck disable=SC1090
  source "$STUDIO_ROOT/config/swarmui.env"
  # shellcheck disable=SC1090
  source "$STUDIO_ROOT/config/comfyui.env"

  : "${STUDIO_ROOT:=$HOME/ai-studio}"
  : "${STUDIO_BOOTSTRAP_DIR:=$(studio_default_bootstrap_dir)}"
  : "${STUDIO_LOG_DIR:=$STUDIO_ROOT/logs}"
  : "${STUDIO_TMP_DIR:=$STUDIO_ROOT/tmp}"
  : "${STUDIO_DATA_DIR:=$STUDIO_ROOT/data}"

  export STUDIO_ROOT STUDIO_BOOTSTRAP_DIR STUDIO_LOG_DIR STUDIO_TMP_DIR STUDIO_DATA_DIR
}

studio_nvidia_available() {
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1
}

studio_tail_log_hint() {
  local file="$1"
  if [[ -f "$file" ]]; then
    studio_warn "Recent log output from $file:"
    tail -n 20 "$file" >&2 || true
  fi
}
