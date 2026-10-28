---
name: agent-health-check
description: Comprehensive diagnostic audit of the agent's toolchains, rule budgets, memory thresholds, privacy airgap, git sync state, and WSL2 resource headroom. Run on-demand or when troubleshooting.
---

# Agent Health Check & System Diagnostics

A deterministic diagnostic skill that audits agent integrity across 5 operational pillars to prevent configuration drift, memory bloat, secret leakage, or environment breakage.

---

## When to Run This Skill

- Manually triggered by Arun: e.g. *"Run agent health check"*, *"Check your health"*, or `doctor.sh`.
- At the start of a major cross-repo migration or after upgrading WSL/Windows.
- When troubleshooting unexpected build errors, sluggish responses, or missing toolchains.

---

## 5 Operational Audit Pillars

The diagnostic engine ([`scripts/doctor.sh`](./scripts/doctor.sh)) performs 21 deterministic checks:

| Pillar | Diagnostic Scope | Failure Threshold |
| :--- | :--- | :--- |
| **1. Toolchains & Runtimes** | Node (fnm), Python embedded (`esptool.py`, `pio`), Android SDK (`adb`), Fast CLI (`rg`, `fd`, `jq`, `tree`). | Missing binary or path resolution failure. |
| **2. Context & Memory** | `AGENTS.md` byte size vs 24KB limit, `MEMORY.md` line count vs 250-line pruning threshold, symlink deduplication. | File size > 24KB or un-deduplicated duplicate files. |
| **3. Privacy & Airgap** | Verifies `~/.gitignore_global` and confirms `Math-Junior` repos (`ProjectAgri`, `CMS`, `RODO-Website`, `Firebase`) have 0 tracked agent files. | Any personal agent file staged or committed to org repos. |
| **4. Upstream Sync** | Verifies `~/.agents` git repository status, clean working tree, and unpushed commit count against `dev-learner-supreme/agents-config`. | Dirty working tree or unpushed commits. |
| **5. WSL2 Headroom** | Available RAM vs 1.5GB starvation threshold, root disk storage headroom on the SSD. | RAM < 1500MB or disk usage > 85%. |

---

## Execution Protocol

Run the diagnostic script directly from the terminal or have the agent execute it:

```bash
~/.agents/skills/agent-health-check/scripts/doctor.sh
# or via shell alias:
agent-doctor
```

---

## Dynamic Capability & Package Inventory

Whenever the diagnostic runs, it executes [`scripts/scan_capabilities.sh`](./scripts/scan_capabilities.sh) to audit newly installed packages in WSL:
- Scans user-installed APT packages (`apt-mark showmanual`).
- Scans `pipx` environments and exposed CLI binaries in `~/.local/bin`.
- Detects Node.js (`fnm`), Java (`openjdk`), Python, Android SDK (`adb`), and Google Cloud SDK.
- Regenerates [`~/.agents/SYSTEM_CAPABILITIES.md`](../../SYSTEM_CAPABILITIES.md) so the agent is always aware of tools you installed on the host.

---

## Automated Remediation Runbook

If any check returns `[WARN]` or `[FAIL]`:

1. **Toolchain Missing:**
   - Node: `fnm install --lts && fnm default lts-latest`
   - ESP32/PlatformIO: `pipx install esptool && pipx install platformio`
   - CLI tools: `sudo apt install -y ripgrep jq fd-find tree`
2. **Memory Over Budget (>250 lines):**
   - Execute the *Safe Pruning Protocol* in [`agent-self-tuning`](../agent-self-tuning/SKILL.md#L72-L85) to consolidate completed task states.
3. **Airgap Breach:**
   - Run `git rm -r --cached .agents MEMORY.md .cursorrules` inside the affected repository, commit, and ensure `~/.gitignore_global` is active.
4. **Unpushed Configuration Commits:**
   - Execute `sync-agent` (or `~/.agents/sync.sh`) to push to the private GitHub remote.
