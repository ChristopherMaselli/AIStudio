# Troubleshooting

## `dotnet-sdk-8.0` was not found

The installer first tries the distro package cache, then falls back to the Microsoft Ubuntu 24.04 package feed. Re-run:

```bash
bash install.sh
```

If the machine is not Ubuntu/Debian-like, this bootstrap is the wrong fit in its current form.

## Python 3.13 was detected

Current SwarmUI Linux guidance warns against Python 3.13. Use Python 3.12 or 3.11 instead, then rerun the installer.

## SwarmUI opens `/Install`

That can still happen on first launch depending on upstream SwarmUI behavior. If it does:

1. Finish the SwarmUI install page.
2. Keep LAN disabled unless you intentionally want exposure.
3. Point it at the local ComfyUI backend or complete the self-start setup.

The bootstrap still ensures the repos, venv, and local runtime scripts are already in place.

## ComfyUI-Copilot failed to install

Copilot is optional here. If its dependency install fails:

1. The core stack can still run.
2. Review the pip error in the install output.
3. Disable it in `$HOME/ai-studio/config/comfyui.env` if you want a cleaner rerun.

## ComfyUI fails after Copilot dependency install

Recent Copilot requirements may downgrade `SQLAlchemy`, while current ComfyUI
needs `SQLAlchemy 2`.

The bootstrap now skips Copilot dependency installation by default. If you
already hit this problem, repair the venv with:

```bash
$HOME/ai-studio/env/comfyui/bin/python -m pip install "SQLAlchemy>=2,<3"
```

## No GPU In The VM

That is expected for a normal smoke-test VM.

- Use `bash smoke_test.sh` there.
- Use `bash validate_gpu.sh` only on a real NVIDIA host.

## A Reinstall Refused To Touch `$HOME/ai-studio`

The installer only refreshes installs that contain the ownership marker:

```text
$HOME/ai-studio/.ai-studio-bootstrap-owned
```

If that marker is missing, the installer assumes the directory may contain unrelated data and stops on purpose.
