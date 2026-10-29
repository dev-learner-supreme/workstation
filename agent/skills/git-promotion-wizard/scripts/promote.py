#!/usr/bin/env python3
"""
Git Promotion Wizard
====================
Deterministic, safe branch promotion across staging and release branches.
Supports: Dev -> Test -> Release (or main).
Strictly adheres to Zero AI attribution (Arun Rao Balappa).
"""

import subprocess
import argparse
import sys
import os

def run_cmd(cmd, cwd=None):
    try:
        res = subprocess.run(cmd, shell=True, text=True, capture_output=True, cwd=cwd)
        return res.returncode == 0, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return False, "", str(e)

def main():
    parser = argparse.ArgumentParser(description="Promote code across branches via GitHub PR")
    parser.add_argument("--repo", default=os.getcwd(), help="Repository root path")
    parser.add_argument("--from", dest="from_branch", required=True, help="Source branch (e.g. Dev)")
    parser.add_argument("--to", dest="to_branch", required=True, help="Target branch (e.g. Test)")
    parser.add_argument("--title", required=True, help="PR title")
    parser.add_argument("--body", default="", help="PR description")
    parser.add_argument("--merge", action="store_true", help="Merge PR immediately after creation")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without executing PR or merge")

    args = parser.parse_args()
    repo = os.path.abspath(args.repo)

    print("╭─  J.A.R.V.I.S. •  Git Promotion Wizard  ────────────────────────╮")
    print(f"│  Repo:   {os.path.basename(repo):<47} │")
    print(f"│  Flow:   {args.from_branch} ➔ {args.to_branch:<40} │")
    print("╰─────────────────────────────────────────────────────────────────╯\n")

    # 1. Check working directory status
    ok, out, err = run_cmd("git status --porcelain", cwd=repo)
    if not ok or out:
        print(f"[✗] Error: Working tree in {repo} is dirty. Commit or stash changes before promotion.")
        if out:
            print(out)
        sys.exit(1)
    print("[✓] Working tree clean.")

    # 2. Fetch origin
    print("[*] Fetching latest refs from origin...")
    ok, _, err = run_cmd("git fetch origin", cwd=repo)
    if not ok:
        print(f"[✗] Git fetch failed: {err}")
        sys.exit(1)

    # 3. Check diff between from and to branches
    ok, ahead_count, _ = run_cmd(f"git rev-list --count origin/{args.to_branch}..origin/{args.from_branch}", cwd=repo)
    if not ok or ahead_count == "0":
        print(f"[!] Warning: origin/{args.from_branch} is not ahead of origin/{args.to_branch}. Nothing to promote.")
        sys.exit(0)
    print(f"[✓] origin/{args.from_branch} has {ahead_count} commit(s) ahead of origin/{args.to_branch}.")

    if args.dry_run:
        print("[!] Dry-run enabled. Skipping PR creation and merge.")
        sys.exit(0)

    # 4. Create PR via gh
    pr_body = args.body or f"Promote changes from {args.from_branch} to {args.to_branch}"
    cmd_pr = f'gh pr create --base "{args.to_branch}" --head "{args.from_branch}" --title "{args.title}" --body "{pr_body}"'
    print("[*] Creating promotion PR...")
    ok, pr_url, err = run_cmd(cmd_pr, cwd=repo)
    if not ok:
        # Check if PR already exists
        if "already exists" in err:
            print(f"[!] PR already exists: {err}")
            # Extract existing PR url/number
            ok_view, pr_url, _ = run_cmd(f'gh pr list --head "{args.from_branch}" --base "{args.to_branch}" --json url --jq ".[0].url"', cwd=repo)
        else:
            print(f"[✗] Failed to create PR: {err}")
            sys.exit(1)
    
    print(f"[✓] PR: {pr_url}")

    # 5. Merge if requested
    if args.merge:
        print("[*] Merging PR...")
        pr_number = pr_url.split("/")[-1]
        cmd_merge = f'gh pr merge {pr_number} --merge --repo $(gh repo view --json nameWithOwner --jq .nameWithOwner)'
        ok, merge_out, err = run_cmd(cmd_merge, cwd=repo)
        if not ok:
            print(f"[✗] PR merge failed: {err}")
            sys.exit(1)
        print(f"[✓] Merged PR #{pr_number} successfully.")

        # Update local target branch
        print(f"[*] Updating local {args.to_branch} branch...")
        run_cmd(f"git checkout {args.to_branch}", cwd=repo)
        run_cmd(f"git pull origin {args.to_branch}", cwd=repo)
        print(f"[✓] Local {args.to_branch} synchronized with origin.")

    print("\n[✓] Promotion pipeline completed successfully.\n")

if __name__ == "__main__":
    main()
