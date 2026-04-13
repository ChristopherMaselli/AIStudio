# Runbook

## Install

From inside this folder:

```bash
bash install.sh
```

The installer will:

- detect whether the machine looks like a smoke-test VM or a GPU host
- install system prerequisites
- install `.NET 8`
- clone SwarmUI and ComfyUI
- build SwarmUI
- create a dedicated ComfyUI venv
- enable ComfyUI Manager support
- clone ComfyUI-Copilot unless disabled
- skip ComfyUI-Copilot Python dependencies unless you explicitly opt in
- write runtime config under `$HOME/ai-studio/config`

## Start The Studio

```bash
bash scripts/start_comfyui.sh
bash scripts/start_swarmui.sh
```

Or use the installed wrappers:

```bash
bash ~/ai-studio/scripts/start_comfyui.sh
bash ~/ai-studio/scripts/start_swarmui.sh
```

## Stop The Studio

```bash
bash scripts/stop_studio.sh
```

## Check Status

```bash
bash scripts/status_studio.sh
```

## Smoke-Test A VM

```bash
bash smoke_test.sh
```

That test verifies:

- SwarmUI files exist
- ComfyUI files exist
- the venv exists
- required commands exist
- ComfyUI can answer locally
- SwarmUI can answer locally

## Validate A Real GPU Host

```bash
bash validate_gpu.sh
```

That script checks:

- `nvidia-smi`
- CUDA visibility inside the ComfyUI venv
- local HTTP readiness for ComfyUI
- local HTTP readiness for SwarmUI

## Upload Models Later

Place models under:

```text
$HOME/ai-studio/data/models
```

Common subfolders created by install:

- `checkpoints/`
- `controlnet/`
- `embeddings/`
- `loras/`
- `upscale_models/`
- `vae/`
- `clip/`
- `clip_vision/`
- `unet/`

## Expose To LAN Intentionally

Edit:

- `$HOME/ai-studio/config/swarmui.env`
- `$HOME/ai-studio/config/comfyui.env`

Change the host from `127.0.0.1` to `0.0.0.0`, then restart the stack.

## Sync Outputs

```bash
bash scripts/sync_outputs.sh /path/to/export
```

That copies the managed output directories to a destination without moving the originals.
