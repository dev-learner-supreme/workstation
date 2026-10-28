---
name: antigravity-whitelist
description: Manage and synchronize Antigravity CLI command permissions and execution whitelist. Use when adding commands to the allowlist, auditing permissions, or ensuring the whitelist persists across workstation reinstalls.
---

# Antigravity CLI Whitelist Manager

This skill manages the command permissions for Antigravity CLI (`agy`), allowing trusted development and administration commands to execute smoothly without repeated confirmation prompts while preserving safety boundaries.

## Architecture

1. **Live Configuration:** Located at `~/.gemini/antigravity-cli/settings.json`.
2. **Versioned Repository Baseline:** Persisted in `workstation` at `agent/integrations/antigravity-settings.json`.
3. **Synchronization Lifecycle:**
   - On cold boot / restoration: `./setup.sh` provisions or merges the whitelist into `~/.gemini/antigravity-cli/settings.json`.
   - On routine sync: `./sync.sh` captures additions made in the live environment back into the git repository.
   - On demand: `manage-whitelist.sh allow <command>` can be invoked to whitelist a new binary prefix.

## Usage

```bash
# List all whitelisted commands
~/.agents/skills/antigravity-whitelist/manage-whitelist.sh list

# Allow a new command prefix (e.g. adb, cargo, docker)
~/.agents/skills/antigravity-whitelist/manage-whitelist.sh allow "cargo"

# Sync changes between repository and live settings
~/.agents/skills/antigravity-whitelist/manage-whitelist.sh sync
```
