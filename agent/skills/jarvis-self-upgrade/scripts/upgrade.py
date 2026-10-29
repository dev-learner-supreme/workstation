#!/usr/bin/env python3
"""
J.A.R.V.I.S. Autonomous Self-Upgrade & Memory Health Protocol
=============================================================
Audits workstation state, active repository drift, operational memory health,
project profiles, command allowlists, and triggers automated upstream synchronization.
Can be executed on-demand, scheduled via systemd user timer, or run post-task.
"""

import os
import sys
import subprocess
import datetime
from pathlib import Path

HOME = Path.home()
AGENTS_DIR = HOME / ".agents"
MEMORY_FILE = AGENTS_DIR / "MEMORY.md"
PROJECTS_DIR = AGENTS_DIR / "projects"
WORK_DIR = HOME / "Work"
SYNC_SCRIPT = AGENTS_DIR / "sync.sh"

def run_cmd(cmd, cwd=None):
    try:
        res = subprocess.run(cmd, cwd=cwd, shell=True, text=True, capture_output=True, timeout=30)
        return res.returncode == 0, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return False, "", str(e)

def audit_memory_health():
    """Ensure MEMORY.md stays under the 250-line limit and has no stale formatting."""
    if not MEMORY_FILE.exists():
        return False, "MEMORY.md missing"
    
    with open(MEMORY_FILE, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    count = len(lines)
    status = f"{count} lines"
    if count > 250:
        status += " (NEEDS PRUNING: exceeds 250-line budget)"
    else:
        status += " (healthy, well within budget)"
    return True, status

def audit_recent_commits():
    """Detect recent commits across core work repositories in the last 7 days."""
    repos = ["Firebase", "CMS", "ProjectAgri", "RODO-Website", "HWCode"]
    recent_activity = {}
    for r in repos:
        repo_path = WORK_DIR / r
        if not repo_path.exists():
            continue
        ok, out, _ = run_cmd("git log --since='7 days ago' --oneline -n 5", cwd=repo_path)
        if ok and out:
            recent_activity[r] = out.split("\n")
    return recent_activity

def audit_whitelist():
    """Verify Antigravity whitelist synchronization."""
    whitelist_script = AGENTS_DIR / "skills" / "antigravity-whitelist" / "scripts" / "manage-whitelist.sh"
    if whitelist_script.exists():
        ok, out, _ = run_cmd(f"bash {whitelist_script} status")
        return ok, out if ok else "Whitelist sync error"
    return True, "manage-whitelist.sh not found (skipped)"

def trigger_sync():
    """Push updates to private workstation repository."""
    if SYNC_SCRIPT.exists():
        ok, out, err = run_cmd(f"bash {SYNC_SCRIPT}")
        return ok, out if ok else err
    return False, "sync.sh not found"

def main():
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"╭─  J.A.R.V.I.S. •  Autonomous Self-Upgrade  ────────────────╮")
    print(f"│  Timestamp: {now_str:<46} │")
    print(f"╰────────────────────────────────────────────────────────────╯\n")

    # 1. Memory Health
    ok, mem_status = audit_memory_health()
    print(f"[1/4] Operational Memory Check:")
    print(f"      Status: {mem_status}")

    # 2. Work Repositories Activity Check
    print(f"\n[2/4] Work Repositories Audit (Past 7 Days):")
    recent = audit_recent_commits()
    if not recent:
        print("      No new commits in the past 7 days across Work repositories.")
    else:
        for repo, commits in recent.items():
            print(f"      • {repo} ({len(commits)} recent commits):")
            for c in commits[:3]:
                print(f"        - {c}")

    # 3. Whitelist Audit
    print(f"\n[3/4] CLI Allowlist & Whitelist Audit:")
    ok_wl, wl_status = audit_whitelist()
    print(f"      {wl_status}")

    # 4. Workstation Upstream Synchronization
    print(f"\n[4/4] Workstation Upstream Synchronization:")
    ok_sync, sync_out = trigger_sync()
    if ok_sync:
        print(f"      ✓ Upstream sync completed successfully.")
        if sync_out:
            print(f"      Output: {sync_out.splitlines()[-1] if sync_out.splitlines() else 'Clean'}")
    else:
        print(f"      ✗ Upstream sync failed: {sync_out}")

    print(f"\n[✓] J.A.R.V.I.S. Self-Upgrade Routine Complete.\n")

if __name__ == "__main__":
    main()
