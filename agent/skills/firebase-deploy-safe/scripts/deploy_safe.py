#!/usr/bin/env python3
"""
Firebase Safe Deployer
======================
Deterministic, isolated Cloud Functions deployment tool.
- Enforces strict environment boundaries (blocks rodo-prod0226).
- Isolates codebase deployments to avoid function name collisions.
- Runs pre-flight test suites prior to deployment.
"""

import subprocess
import argparse
import sys
import os

FIREBASE_DIR = "/home/arun/Work/Firebase"
PROD_PROJECT = "rodo-prod0226"

def run_cmd(cmd, cwd=None):
    try:
        res = subprocess.run(cmd, shell=True, text=True, capture_output=True, cwd=cwd)
        return res.returncode == 0, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return False, "", str(e)

def main():
    parser = argparse.ArgumentParser(description="Safely deploy Firebase Cloud Functions")
    parser.add_argument("--project", required=True, choices=["final-15ec5", "project-agri-test-84e72", "rodo-prod0226"], help="GCP / Firebase target project")
    parser.add_argument("--codebase", required=True, choices=["functions-core", "functions-cron", "functions-cms", "functions-website"], help="Codebase namespace")
    parser.add_argument("--only", default="", help="Optional comma-separated list of functions within the codebase")
    parser.add_argument("--skip-tests", action="store_true", help="Skip pre-flight test suites")
    parser.add_argument("--force-prod", action="store_true", help="Explicit override for production (requires manual confirmation)")

    args = parser.parse_args()

    print("╭─  J.A.R.V.I.S. •  Firebase Safe Deployer  ──────────────────────╮")
    print(f"│  Project:  {args.project:<47} │")
    print(f"│  Codebase: {args.codebase:<47} │")
    print("╰─────────────────────────────────────────────────────────────────╯\n")

    # 1. Production Barrier
    if args.project == PROD_PROJECT and not args.force_prod:
        print("[✗] SECURITY BLOCK: Deployment to Production (rodo-prod0226) is strictly prohibited without explicit confirmation.")
        sys.exit(1)

    # 2. Pre-flight Tests for functions-core
    if args.codebase == "functions-core" and not args.skip_tests:
        print("[*] Running pre-flight unit tests in functions-core...")
        core_dir = os.path.join(FIREBASE_DIR, "functions-core")
        ok, out, err = run_cmd("npm test", cwd=core_dir)
        if not ok:
            print("[✗] Pre-flight tests failed! Aborting deployment.")
            print(err or out)
            sys.exit(1)
        print("[✓] Pre-flight tests passed successfully.")

    # 3. Formulate targeted deploy command
    if args.only:
        funcs = ",".join(f"{args.codebase}:{fn.strip()}" for fn in args.only.split(","))
        target = f"functions:{funcs}"
    else:
        target = f"functions:{args.codebase}"

    cmd_deploy = f"firebase deploy --project {args.project} --only {target}"
    print(f"[*] Executing isolated deploy: {cmd_deploy}...")

    # Execute deployment with real-time streaming
    p = subprocess.Popen(cmd_deploy, shell=True, cwd=FIREBASE_DIR, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    for line in iter(p.stdout.readline, ''):
        sys.stdout.write(line)
        sys.stdout.flush()
    p.stdout.close()
    return_code = p.wait()

    if return_code != 0:
        print(f"\n[✗] Deployment exited with code {return_code}.")
        sys.exit(return_code)

    print("\n[✓] Safe deployment completed successfully.\n")

if __name__ == "__main__":
    main()
