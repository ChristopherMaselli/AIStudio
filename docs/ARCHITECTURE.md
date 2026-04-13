# Architecture

This bootstrap is designed around a simple split:

- A GPU host runs the actual AI stack.
- A client machine uses a browser and SSH to control it.
- A local VM is mainly for bootstrap validation, scripting, and dry runs.

## Stack Roles

- `SwarmUI` is the main frontend and operator-facing UI.
- `ComfyUI` is the backend engine.
- `ComfyUI Manager` is enabled so node management stays sane.
- `ComfyUI-Copilot` is optional helper tooling, not a hard dependency.

## Install Ownership

Everything owned by the installed stack lives under:

```text
$HOME/ai-studio
```

That root contains:

- `apps/`: cloned application repos
- `config/`: runtime config files
- `data/`: models, inputs, outputs, and ComfyUI data
- `docs/`: copied runbooks and references
- `env/`: Python virtual environment(s)
- `logs/`: runtime logs
- `scripts/`: runtime wrappers that call back into this bootstrap folder
- `tmp/`: pid files and temporary runtime data
- `backups/`: reserved for reversible cleanup workflows

## Deployment Model

For a rented GPU server:

1. Copy this `ai-studio-bootstrap/` folder onto the server.
2. Run `bash install.sh`.
3. Upload only the models you want.
4. Start ComfyUI and SwarmUI.
5. Use the UI through a browser or SSH tunnel.
6. Destroy the server when finished.

For a VM smoke test:

1. Copy this folder into the VM.
2. Run `bash install.sh`.
3. Run `bash smoke_test.sh`.
4. Do not treat that VM as proof of real NVIDIA runtime health.

## Network Posture

The default bind is local-only.

- SwarmUI defaults to `127.0.0.1:7801`
- ComfyUI defaults to `127.0.0.1:8188`

If you want LAN access later, change the host values in:

- `$HOME/ai-studio/config/swarmui.env`
- `$HOME/ai-studio/config/comfyui.env`

That keeps exposure deliberate rather than accidental.
