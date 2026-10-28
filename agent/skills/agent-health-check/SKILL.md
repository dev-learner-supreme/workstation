---
name: agent-health-check
description: Comprehensive diagnostic audit of the agent's toolchains, rule budgets, memory thresholds, privacy airgap, git sync state, and Omarchy hardware headroom. Run on-demand or when troubleshooting.
---

# Agent Health Check & System Diagnostics

A deterministic diagnostic skill that audits agent integrity across 5 operational pillars to prevent configuration drift, memory bloat, secret leakage, or environment breakage on Omarchy Linux.

---

## When to Run This Skill

- Manually triggered by Arun: e.g. *"Run agent health check"*, *"Check your health"*, or `doctor.sh`.
- At the start of a major cross-repo migration or after system package upgrades.
- When troubleshooting unexpected build errors, sluggish responses, or missing toolchains.

---

## 5 Operational Audit Pillars

The diagnostic engine ([`scripts/doctor.sh`](./scripts/doctor.sh)) performs 21 deterministic checks:

| Pillar | Diagnostic Scope | Failure Threshold |
| :--- | :--- | :--- |
| **1. Toolchains & Runtimes** | Node (system/mise), Python embedded (`esptool.py`, `pio`), Android SDK (`adb`), Fast CLI (`rg`, `fd`, `jq`, `tree`). | Missing binary or path resolution failure. |
| **2. Context & Memory** | `AGENTS.md` byte size vs 24KB limit, `MEMORY.md` line count vs 250-line pruning threshold, symlink deduplication across canonical entry points. | File size > 24KB or un-deduplicated duplicate files. |
| **3. Privacy & Airgap** | Verifies `~/.config/git/ignore` and confirms `Math-Junior` repos (`ProjectAgri`, `CMS`, `RODO-Website`, `Firebase`) have 0 tracked agent files. | Any personal agent file staged or committed to org repos. |
| **4. Upstream Sync** | Verifies `~/.agents` git repository tracking, clean working tree, and upstream connectivity. | Dirty working tree or untracked changes. |
| **5. Hardware & Headroom** | Available RAM vs 1.5GB starvation threshold, root NVMe disk storage headroom on Btrfs. | RAM < 1500MB or disk usage > 85%. |

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

Whenever the diagnostic runs, it executes [`scripts/scan_capabilities.sh`](./scripts/scan_capabilities.sh) to audit installed packages:
- Audits explicit pacman packages (`pacman -Qqe`).
- Audits CLI runtimes and SDKs.
