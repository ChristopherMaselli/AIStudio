#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$SCRIPT_DIR"

# shellcheck disable=SC1091
source "$BOOTSTRAP_DIR/scripts/common.sh"

MODE="auto"
WIPE_DATA=0
INSTALL_COPILOT=1
INSTALL_COPILOT_DEPS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --smoke-test)
      MODE="smoke-test"
      shift
      ;;
    --gpu)
      MODE="gpu"
      shift
      ;;
    --wipe-data)
      WIPE_DATA=1
      shift
      ;;
    --no-copilot)
      INSTALL_COPILOT=0
      shift
      ;;
    --with-copilot-deps)
      INSTALL_COPILOT_DEPS=1
      shift
      ;;
    *)
      studio_die "Unknown option: $1"
      ;;
  esac
done

if [[ "$MODE" != "auto" && "$MODE" != "smoke-test" && "$MODE" != "gpu" ]]; then
  studio_die "Invalid mode '$MODE'. Use auto, smoke-test, or gpu."
fi

studio_init_sudo

STUDIO_ROOT="${STUDIO_ROOT:-$HOME/ai-studio}"
BOOTSTRAP_DIR="$(cd "$BOOTSTRAP_DIR" && pwd)"
MARKER_FILE="$STUDIO_ROOT/.ai-studio-bootstrap-owned"
MANIFEST_DIR="$BOOTSTRAP_DIR/manifest"
PATHS_MANIFEST="$MANIFEST_DIR/installed_paths.txt"
PACKAGES_MANIFEST="$MANIFEST_DIR/installed_packages.txt"
SYMLINKS_MANIFEST="$MANIFEST_DIR/created_symlinks.txt"
SERVICES_MANIFEST="$MANIFEST_DIR/created_services.txt"

BASE_PACKAGES=(
  apt-transport-https
  build-essential
  ca-certificates
  curl
  ffmpeg
  git
  git-lfs
  gpg
  jq
  procps
  python3
  python3-pip
  python3-venv
  rsync
  unzip
  wget
)

track_path() {
  local path="$1"
  if ! grep -Fxq "$path" "$PATHS_MANIFEST" 2>/dev/null; then
    printf '%s\n' "$path" >>"$PATHS_MANIFEST"
  fi
}

reset_manifest() {
  mkdir -p "$MANIFEST_DIR"
  printf '# Paths created by ai-studio-bootstrap on %s\n' "$(date -Is)" >"$PATHS_MANIFEST"
  printf '# Apt packages newly installed by ai-studio-bootstrap on %s\n' "$(date -Is)" >"$PACKAGES_MANIFEST"
  printf '# ai-studio-bootstrap does not create symlinks by default.\n' >"$SYMLINKS_MANIFEST"
  printf '# ai-studio-bootstrap does not create system services by default.\n' >"$SERVICES_MANIFEST"
}

capture_installed_packages() {
  local target="$1"
  dpkg-query -W -f='${binary:Package}\n' | LC_ALL=C sort -u >"$target"
}

apt_install() {
  "${STUDIO_SUDO[@]}" apt-get install -y "$@"
}

ensure_ubuntu_like() {
  if [[ ! -f /etc/os-release ]]; then
    studio_die "Unable to detect Linux distribution."
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID_LIKE:-}" != *debian* && "${ID:-}" != "ubuntu" && "${ID:-}" != "debian" ]]; then
    studio_die "This bootstrap currently supports Ubuntu/Debian-style systems."
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    studio_die "apt-get is required on this machine."
  fi
}

ensure_dotnet_sdk() {
  if command -v dotnet >/dev/null 2>&1 && dotnet --list-sdks 2>/dev/null | grep -q '^8\.'; then
    return 0
  fi

  if apt-cache show dotnet-sdk-8.0 >/dev/null 2>&1; then
    apt_install dotnet-sdk-8.0
  else
    local tmp_deb
    tmp_deb="$(mktemp /tmp/packages-microsoft-prod.XXXXXX.deb)"
    wget -qO "$tmp_deb" "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb"
    "${STUDIO_SUDO[@]}" dpkg -i "$tmp_deb"
    rm -f "$tmp_deb"
    "${STUDIO_SUDO[@]}" apt-get update
    apt_install dotnet-sdk-8.0
  fi

  if ! command -v dotnet >/dev/null 2>&1 || ! dotnet --list-sdks 2>/dev/null | grep -q '^8\.'; then
    studio_die ".NET 8 SDK install did not complete successfully."
  fi
}

ensure_safe_root() {
  case "$STUDIO_ROOT" in
    ""|"/"|"$HOME")
      studio_die "Refusing to install into unsafe root '$STUDIO_ROOT'."
      ;;
  esac
}

refresh_existing_install() {
  if [[ -e "$STUDIO_ROOT" && ! -f "$MARKER_FILE" ]]; then
    studio_die "$STUDIO_ROOT already exists but is not marked as managed by ai-studio-bootstrap."
  fi

  if [[ -f "$MARKER_FILE" ]]; then
    studio_log "Existing managed install detected. Refreshing managed files."
    if [[ -f "$STUDIO_ROOT/config/studio.env" ]]; then
      STUDIO_ENV_FILE="$STUDIO_ROOT/config/studio.env" bash "$BOOTSTRAP_DIR/scripts/stop_studio.sh" >/dev/null 2>&1 || true
    fi

    rm -rf \
      "$STUDIO_ROOT/apps" \
      "$STUDIO_ROOT/env" \
      "$STUDIO_ROOT/logs" \
      "$STUDIO_ROOT/tmp" \
      "$STUDIO_ROOT/docs" \
      "$STUDIO_ROOT/scripts" \
      "$STUDIO_ROOT/config"

    if [[ "$WIPE_DATA" -eq 1 ]]; then
      rm -rf "$STUDIO_ROOT/data" "$STUDIO_ROOT/backups"
    fi
  fi
}

create_layout() {
  mkdir -p \
    "$STUDIO_ROOT/apps" \
    "$STUDIO_ROOT/backups" \
    "$STUDIO_ROOT/config/examples" \
    "$STUDIO_ROOT/data/inputs" \
    "$STUDIO_ROOT/data/models/checkpoints" \
    "$STUDIO_ROOT/data/models/controlnet" \
    "$STUDIO_ROOT/data/models/embeddings" \
    "$STUDIO_ROOT/data/models/loras" \
    "$STUDIO_ROOT/data/models/upscale_models" \
    "$STUDIO_ROOT/data/models/vae" \
    "$STUDIO_ROOT/data/models/clip" \
    "$STUDIO_ROOT/data/models/clip_vision" \
    "$STUDIO_ROOT/data/models/unet" \
    "$STUDIO_ROOT/data/outputs/comfyui" \
    "$STUDIO_ROOT/data/comfyui-user" \
    "$STUDIO_ROOT/docs" \
    "$STUDIO_ROOT/env" \
    "$STUDIO_ROOT/logs" \
    "$STUDIO_ROOT/scripts" \
    "$STUDIO_ROOT/tmp"

  while read -r path; do
    [[ -n "$path" ]] && track_path "$path"
  done <<EOF
$STUDIO_ROOT
$STUDIO_ROOT/apps
$STUDIO_ROOT/backups
$STUDIO_ROOT/config
$STUDIO_ROOT/config/examples
$STUDIO_ROOT/data
$STUDIO_ROOT/data/inputs
$STUDIO_ROOT/data/models
$STUDIO_ROOT/data/models/checkpoints
$STUDIO_ROOT/data/models/controlnet
$STUDIO_ROOT/data/models/embeddings
$STUDIO_ROOT/data/models/loras
$STUDIO_ROOT/data/models/upscale_models
$STUDIO_ROOT/data/models/vae
$STUDIO_ROOT/data/models/clip
$STUDIO_ROOT/data/models/clip_vision
$STUDIO_ROOT/data/models/unet
$STUDIO_ROOT/data/outputs
$STUDIO_ROOT/data/outputs/comfyui
$STUDIO_ROOT/data/comfyui-user
$STUDIO_ROOT/docs
$STUDIO_ROOT/env
$STUDIO_ROOT/logs
$STUDIO_ROOT/scripts
$STUDIO_ROOT/tmp
EOF
}

clone_or_update_repo() {
  local repo_url="$1"
  local branch="$2"
  local target_dir="$3"

  if [[ ! -d "$target_dir/.git" ]]; then
    git clone --depth 1 --branch "$branch" "$repo_url" "$target_dir"
  else
    git -C "$target_dir" fetch origin "$branch" --depth 1
    git -C "$target_dir" checkout "$branch"
    git -C "$target_dir" pull --ff-only origin "$branch"
  fi

  track_path "$target_dir"
}

write_runtime_wrappers() {
  write_wrapper() {
    local target="$1"
    local command_path="$2"
    cat >"$target" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec bash "$command_path" "\$@"
EOF
    chmod +x "$target"
    track_path "$target"
  }

  write_wrapper "$STUDIO_ROOT/scripts/start_swarmui.sh" "$BOOTSTRAP_DIR/scripts/start_swarmui.sh"
  write_wrapper "$STUDIO_ROOT/scripts/start_comfyui.sh" "$BOOTSTRAP_DIR/scripts/start_comfyui.sh"
  write_wrapper "$STUDIO_ROOT/scripts/stop_studio.sh" "$BOOTSTRAP_DIR/scripts/stop_studio.sh"
  write_wrapper "$STUDIO_ROOT/scripts/status_studio.sh" "$BOOTSTRAP_DIR/scripts/status_studio.sh"
  write_wrapper "$STUDIO_ROOT/scripts/sync_outputs.sh" "$BOOTSTRAP_DIR/scripts/sync_outputs.sh"
  write_wrapper "$STUDIO_ROOT/scripts/cleanup_temp.sh" "$BOOTSTRAP_DIR/scripts/cleanup_temp.sh"
  write_wrapper "$STUDIO_ROOT/scripts/smoke_test.sh" "$BOOTSTRAP_DIR/smoke_test.sh"
  write_wrapper "$STUDIO_ROOT/scripts/validate_gpu.sh" "$BOOTSTRAP_DIR/validate_gpu.sh"
}

write_env_files() {
  local studio_mode="$1"
  local comfy_device_mode="$2"
  local swarm_host="127.0.0.1"
  local comfy_host="127.0.0.1"

  cat >"$STUDIO_ROOT/config/studio.env" <<EOF
STUDIO_ROOT="$STUDIO_ROOT"
STUDIO_BOOTSTRAP_DIR="$BOOTSTRAP_DIR"
STUDIO_MODE="$studio_mode"
STUDIO_EXPOSE_TO_LAN="0"
STUDIO_LOG_DIR="$STUDIO_ROOT/logs"
STUDIO_TMP_DIR="$STUDIO_ROOT/tmp"
STUDIO_DATA_DIR="$STUDIO_ROOT/data"
STUDIO_SYNC_DEST=""
EOF

  cat >"$STUDIO_ROOT/config/swarmui.env" <<EOF
STUDIO_SWARMUI_REPO="https://github.com/mcmonkeyprojects/SwarmUI.git"
STUDIO_SWARMUI_BRANCH="master"
STUDIO_SWARMUI_HOST="$swarm_host"
STUDIO_SWARMUI_PORT="7801"
STUDIO_SWARMUI_ARGS=""
EOF

  cat >"$STUDIO_ROOT/config/comfyui.env" <<EOF
STUDIO_COMFYUI_REPO="https://github.com/comfyanonymous/ComfyUI.git"
STUDIO_COMFYUI_BRANCH="master"
STUDIO_COMFYUI_HOST="$comfy_host"
STUDIO_COMFYUI_PORT="8188"
STUDIO_COMFYUI_ARGS=""
STUDIO_COMFYUI_ENABLE_MANAGER="1"
STUDIO_COMFYUI_COPILOT_ENABLED="$INSTALL_COPILOT"
STUDIO_COMFYUI_COPILOT_DEPS_ENABLED="$INSTALL_COPILOT_DEPS"
STUDIO_COMFYUI_COPILOT_REPO="https://github.com/AIDC-AI/ComfyUI-Copilot.git"
STUDIO_COMFYUI_DEVICE_MODE="$comfy_device_mode"
STUDIO_COMFYUI_CUDA_DEVICE=""
STUDIO_TORCH_INDEX_URL_GPU="https://download.pytorch.org/whl/cu128"
STUDIO_TORCH_INDEX_URL_CPU="https://download.pytorch.org/whl/cpu"
EOF

  cp -f "$BOOTSTRAP_DIR/config/"*.example "$STUDIO_ROOT/config/examples/"
  track_path "$STUDIO_ROOT/config/studio.env"
  track_path "$STUDIO_ROOT/config/swarmui.env"
  track_path "$STUDIO_ROOT/config/comfyui.env"
}

copy_docs() {
  cp -f "$BOOTSTRAP_DIR/README.md" "$STUDIO_ROOT/docs/BOOTSTRAP_README.md"
  cp -f "$BOOTSTRAP_DIR/docs/"*.md "$STUDIO_ROOT/docs/"
  track_path "$STUDIO_ROOT/docs/BOOTSTRAP_README.md"
}

write_marker() {
  cat >"$MARKER_FILE" <<EOF
BOOTSTRAP_OWNER=ai-studio-bootstrap
BOOTSTRAP_DIR="$BOOTSTRAP_DIR"
STUDIO_ROOT="$STUDIO_ROOT"
INSTALLED_AT="$(date -Is)"
EOF
  track_path "$MARKER_FILE"
}

install_torch() {
  local python_bin="$1"
  local install_mode="$2"
  local index_url

  if [[ "$install_mode" == "cpu" ]]; then
    index_url="https://download.pytorch.org/whl/cpu"
  else
    index_url="https://download.pytorch.org/whl/cu128"
  fi

  if ! "$python_bin" -m pip install --upgrade --index-url "$index_url" torch torchvision torchaudio; then
    if [[ "$install_mode" == "gpu" ]]; then
      studio_warn "GPU torch wheel install failed from $index_url. Falling back to the default index."
      "$python_bin" -m pip install --upgrade torch torchvision torchaudio
    else
      studio_die "CPU torch wheel install failed from $index_url."
    fi
  fi
}

ensure_ubuntu_like
ensure_safe_root
reset_manifest

before_packages_file="$(mktemp)"
after_packages_file="$(mktemp)"
capture_installed_packages "$before_packages_file"

studio_log "Installing base system dependencies"
"${STUDIO_SUDO[@]}" apt-get update
apt_install "${BASE_PACKAGES[@]}"
ensure_dotnet_sdk
capture_installed_packages "$after_packages_file"

comm -13 "$before_packages_file" "$after_packages_file" >>"$PACKAGES_MANIFEST" || true
rm -f "$before_packages_file" "$after_packages_file"

if command -v git-lfs >/dev/null 2>&1; then
  git lfs install --skip-repo >/dev/null 2>&1 || true
fi

PYTHON_VERSION="$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
if python3 -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 13) else 1)'; then
  studio_die "Python 3.13 is currently unsupported by SwarmUI's Linux install guidance."
fi

GPU_DETECTED="no"
if studio_nvidia_available; then
  GPU_DETECTED="yes"
fi

if [[ "$MODE" == "auto" ]]; then
  if [[ "$GPU_DETECTED" == "yes" ]]; then
    MODE="gpu"
  else
    MODE="smoke-test"
  fi
fi

COMFY_DEVICE_MODE="auto"
if [[ "$MODE" == "smoke-test" ]]; then
  COMFY_DEVICE_MODE="cpu"
fi

refresh_existing_install
create_layout
write_env_files "$MODE" "$COMFY_DEVICE_MODE"
write_runtime_wrappers
copy_docs
write_marker

SWARM_DIR="$STUDIO_ROOT/apps/SwarmUI"
COMFY_DIR="$STUDIO_ROOT/apps/ComfyUI"
VENV_DIR="$STUDIO_ROOT/env/comfyui"

studio_log "Cloning or updating SwarmUI"
clone_or_update_repo "https://github.com/mcmonkeyprojects/SwarmUI.git" "master" "$SWARM_DIR"

studio_log "Cloning or updating ComfyUI"
clone_or_update_repo "https://github.com/comfyanonymous/ComfyUI.git" "master" "$COMFY_DIR"

studio_log "Building SwarmUI"
dotnet build "$SWARM_DIR/src/SwarmUI.csproj" --configuration Release -o "$SWARM_DIR/src/bin/live_release"
git -C "$SWARM_DIR" rev-parse HEAD > "$SWARM_DIR/src/bin/last_build"
track_path "$SWARM_DIR/src/bin/live_release"
track_path "$SWARM_DIR/src/bin/last_build"

studio_log "Creating ComfyUI virtual environment"
python3 -m venv "$VENV_DIR"
track_path "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel

if [[ "$MODE" == "smoke-test" ]]; then
  studio_log "Installing CPU PyTorch wheels for smoke-test mode"
  install_torch "$VENV_DIR/bin/python" "cpu"
else
  studio_log "Installing GPU-oriented PyTorch wheels"
  install_torch "$VENV_DIR/bin/python" "gpu"
fi

studio_log "Installing ComfyUI requirements"
"$VENV_DIR/bin/python" -m pip install -r "$COMFY_DIR/requirements.txt"

manager_mode="builtin"
if [[ -f "$COMFY_DIR/manager_requirements.txt" ]]; then
  studio_log "Enabling current ComfyUI Manager support"
  "$VENV_DIR/bin/python" -m pip install -r "$COMFY_DIR/manager_requirements.txt"
else
  manager_mode="legacy-clone"
  studio_log "Falling back to legacy ComfyUI-Manager clone"
  mkdir -p "$COMFY_DIR/custom_nodes"
  clone_or_update_repo "https://github.com/ltdrdata/ComfyUI-Manager.git" "main" "$COMFY_DIR/custom_nodes/ComfyUI-Manager"
  if [[ -f "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt" ]]; then
    "$VENV_DIR/bin/python" -m pip install -r "$COMFY_DIR/custom_nodes/ComfyUI-Manager/requirements.txt"
  fi
fi

copilot_status="disabled"
if [[ "$INSTALL_COPILOT" -eq 1 ]]; then
  studio_log "Installing ComfyUI-Copilot repository"
  mkdir -p "$COMFY_DIR/custom_nodes"
  clone_or_update_repo "https://github.com/AIDC-AI/ComfyUI-Copilot.git" "main" "$COMFY_DIR/custom_nodes/ComfyUI-Copilot"
  copilot_status="repo-cloned"
  if [[ "$INSTALL_COPILOT_DEPS" -eq 1 && -f "$COMFY_DIR/custom_nodes/ComfyUI-Copilot/requirements.txt" ]]; then
    studio_log "Installing ComfyUI-Copilot Python dependencies"
    if "$VENV_DIR/bin/python" -m pip install -r "$COMFY_DIR/custom_nodes/ComfyUI-Copilot/requirements.txt"; then
      copilot_status="installed"
    else
      studio_warn "ComfyUI-Copilot dependency install failed. Core studio install will continue."
      copilot_status="install-failed"
    fi
  elif [[ "$INSTALL_COPILOT_DEPS" -eq 0 ]]; then
    studio_warn "ComfyUI-Copilot dependencies were skipped by default to avoid destabilizing ComfyUI."
  fi
fi

studio_log "Install complete"
cat <<EOF

Install root: $STUDIO_ROOT
Mode: $MODE
Python version: $PYTHON_VERSION
GPU detected: $GPU_DETECTED
SwarmUI manager mode: $manager_mode
ComfyUI-Copilot: $copilot_status

Launch commands:
  bash "$STUDIO_ROOT/scripts/start_comfyui.sh"
  bash "$STUDIO_ROOT/scripts/start_swarmui.sh"

Local URLs:
  SwarmUI: http://127.0.0.1:7801
  ComfyUI: http://127.0.0.1:8188

Next recommended checks:
  bash "$BOOTSTRAP_DIR/smoke_test.sh"
  bash "$BOOTSTRAP_DIR/validate_gpu.sh"   # only on a real NVIDIA host
EOF
