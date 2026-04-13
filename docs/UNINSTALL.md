# Uninstall

## Safe Default

Run:

```bash
bash uninstall.sh
```

This will:

- stop SwarmUI and ComfyUI
- remove the managed install root at `$HOME/ai-studio`
- remove any manifest-listed symlinks or services if they exist
- leave shared system packages in place
- keep this bootstrap folder so it can be reused

## Purge Mode

To also remove packages that were newly installed by this bootstrap:

```bash
bash uninstall.sh --purge-system-deps
```

Only packages recorded in `manifest/installed_packages.txt` are targeted.

## Archive Before Removal

If you want a quick archive of config, outputs, and model directories before removal:

```bash
bash uninstall.sh --archive-data
```

The archive is written under:

```text
manifest/backups/
```

## Back Up First If Needed

Before uninstalling, back up anything you want to keep:

- uploaded models
- outputs
- edited config
- local notes or prompts stored under `$HOME/ai-studio`

## Intentional Limits

The uninstaller is intentionally narrow.

- It does not delete this bootstrap folder.
- It does not blindly remove random Python packages.
- It does not touch unrelated home-directory files.
