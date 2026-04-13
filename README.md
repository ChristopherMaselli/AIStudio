# AI Studio Bootstrap

Portable Linux bootstrap for an Animation Studio stack built around:

- SwarmUI as the main frontend
- ComfyUI as the backend engine
- ComfyUI Manager support
- ComfyUI-Copilot as an optional helper node

Models are intentionally not bundled.

## Quick Start

On a fresh Ubuntu-based VM or server:

```bash
bash install.sh
bash smoke_test.sh
```

On a real GPU host:

```bash
bash install.sh
bash validate_gpu.sh
```

To start the stack after install:

```bash
bash scripts/start_comfyui.sh
bash scripts/start_swarmui.sh
```

To stop it:

```bash
bash scripts/stop_studio.sh
```

To remove everything this bootstrap installed under `$HOME/ai-studio`:

```bash
bash uninstall.sh
```

To also remove system packages that were newly installed by this bootstrap:

```bash
bash uninstall.sh --purge-system-deps
```

## What This Bundle Owns

Everything app-owned lives under:

```text
$HOME/ai-studio
```

The install creates managed subfolders for apps, config, logs, temp data, docs,
runtime wrappers, and model/output storage. The bootstrap folder itself stays
portable and can be copied onto a fresh machine unchanged.

## Main Files

- `install.sh`: full install and bootstrap
- `uninstall.sh`: scoped cleanup for everything this bootstrap installed
- `smoke_test.sh`: no-GPU validation for a VM or control-seat machine
- `validate_gpu.sh`: GPU checks for a real NVIDIA host
- `config/*.example`: editable config templates
- `manifest/*`: install ownership and cleanup manifests
- `scripts/`: start, stop, status, sync, and cleanup helpers
- `docs/`: architecture, runbook, uninstall notes, troubleshooting

## Notes

- Default network binding stays local-only.
- LAN exposure is a config change, not the default.
- Re-running `install.sh` refreshes the managed app/runtime files. Use
  `bash uninstall.sh` for a full wipe.
- ComfyUI-Copilot is treated as optional helper tooling. By default the repo is
  cloned without installing its Python dependencies so the core ComfyUI
  environment stays stable.
# AIStudio
# AIStudio
