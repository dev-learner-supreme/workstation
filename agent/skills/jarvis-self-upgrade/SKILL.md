---
name: jarvis-self-upgrade
description: Autonomous weekly and post-task self-upgrade protocol for J.A.R.V.I.S. Audits recent git commits, closed PRs, infrastructure drift, prunes MEMORY.md, enriches project profiles, checks whitelist sync, and pushes upstream to the workstation repository.
---

# J.A.R.V.I.S. Autonomous Self-Upgrade Protocol

A proactive, self-evolving maintenance and consolidation protocol. Mandated by the J.A.R.V.I.S. Core Mandate to prevent knowledge stagnation and eliminate manual prompting for memory updates.

---

## 1. Operating Principles

1. **Autonomous Post-Task Execution (Zero Prompt Delay):**
   - The agent MUST NOT wait for Arun to ask "did you update your memory?".
   - The exact moment a feature PR is merged, a backfill is run, or an environment bug is resolved, immediately consolidate operational invariants into [`MEMORY.md`](file:///home/arun/.agents/MEMORY.md), update project profiles, and sync upstream.
2. **Weekly Baseline Sweep:**
   - Runs automatically on a weekly schedule via systemd user timer (`jarvis-self-upgrade.timer`) or via Antigravity timer.
   - Audits git commit logs across all active repositories to catch changes that occurred outside agent sessions.
   - Enforces the 250-line pruning threshold on [`MEMORY.md`](file:///home/arun/.agents/MEMORY.md).
   - Verifies CLI whitelist synchronization.
   - Pushes snapshots to `dev-learner-supreme/workstation`.

---

## 2. Execution Triggers

* **On-Demand / Manual:**
  ```bash
  python3 ~/.agents/skills/jarvis-self-upgrade/scripts/upgrade.py
  ```
* **Scheduled (Systemd User Timer):**
  - Timer: `~/.config/systemd/user/jarvis-self-upgrade.timer`
  - Schedule: Every Monday at 04:00 AM IST (Weekly)
* **Post-Task Autonomous Checklist:**
  1. Did this task alter an architectural standard, schema, or API payload? -> Update repository profile under `~/.agents/projects/`.
  2. Did this task reveal a new environment quirk or deployment failure mode? -> Record in `~/.agents/MEMORY.md`.
  3. Execute `bash ~/.agents/sync.sh` to push commits immediately.

---

## 3. Maintenance Script Structure

The underlying audit script is located at [`scripts/upgrade.py`](file:///home/arun/.agents/skills/jarvis-self-upgrade/scripts/upgrade.py):
1. **Memory Health Check:** Validates `MEMORY.md` length (<250 lines) and structural formatting.
2. **Work Repositories Audit:** Gathers the last 7 days of commits across `Firebase`, `CMS`, `ProjectAgri`, `RODO-Website`, and `HWCode`.
3. **Whitelist Parity:** Verifies `settings.json` against `antigravity-whitelist`.
4. **Upstream Git Sync:** Runs `~/.agents/sync.sh` to push updates directly to `dev-learner-supreme/workstation`.
