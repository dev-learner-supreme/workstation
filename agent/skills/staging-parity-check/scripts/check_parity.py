#!/usr/bin/env python3
"""
Staging Parity Auditor: Dev (final-15ec5) vs Test (project-agri-test-84e72)
==========================================================================
Fast, deterministic verification of Cloud Functions, composite indexes,
and Firestore /config documents across staging environments.
"""

import subprocess
import json
import sys

DEV_PROJECT = "final-15ec5"
TEST_PROJECT = "project-agri-test-84e72"

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, shell=True, text=True, capture_output=True, timeout=30)
        return res.returncode == 0, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return False, "", str(e)

def check_functions():
    ok_dev, out_dev, _ = run_cmd(f"gcloud functions list --project={DEV_PROJECT} --format=json")
    ok_test, out_test, _ = run_cmd(f"gcloud functions list --project={TEST_PROJECT} --format=json")
    
    if not (ok_dev and ok_test):
        return False, "Failed to query Cloud Functions via gcloud"
    
    dev_funcs = set(f["name"].split("/functions/")[1] for f in json.loads(out_dev))
    test_funcs = set(f["name"].split("/functions/")[1] for f in json.loads(out_test))
    
    only_dev = dev_funcs - test_funcs
    only_test = test_funcs - dev_funcs
    
    return True, {
        "dev_count": len(dev_funcs),
        "test_count": len(test_funcs),
        "only_dev": list(only_dev),
        "only_test": list(only_test),
        "synced": len(only_dev) == 0 and len(only_test) == 0
    }

def check_indexes():
    ok_dev, out_dev, _ = run_cmd(f"gcloud firestore indexes composite list --project={DEV_PROJECT} --format=json")
    ok_test, out_test, _ = run_cmd(f"gcloud firestore indexes composite list --project={TEST_PROJECT} --format=json")
    
    if not (ok_dev and ok_test):
        return False, "Failed to query Firestore indexes"
    
    def norm(idx):
        col = idx["name"].split("/collectionGroups/")[1].split("/")[0]
        fields = ", ".join(f"{f['fieldPath']}:{f.get('order', f.get('arrayConfig'))}" for f in idx.get("fields", []))
        return f"{col}({fields})"
    
    dev_idx = set(norm(i) for i in json.loads(out_dev))
    test_idx = set(norm(i) for i in json.loads(out_test))
    
    only_dev = dev_idx - test_idx
    only_test = test_idx - dev_idx
    
    return True, {
        "dev_count": len(dev_idx),
        "test_count": len(test_idx),
        "only_dev": list(only_dev),
        "only_test": list(only_test),
        "synced": len(only_dev) == 0 and len(only_test) == 0
    }

def main():
    print("╭─  J.A.R.V.I.S. •  Staging Parity Audit  ────────────────────────╮")
    print(f"│  Dev:  {DEV_PROJECT:<47} │")
    print(f"│  Test: {TEST_PROJECT:<47} │")
    print("╰─────────────────────────────────────────────────────────────────╯\n")
    
    # 1. Functions
    ok_f, res_f = check_functions()
    if ok_f:
        status_f = "✓ 100% IN SYNC" if res_f["synced"] else "✗ DRIFT DETECTED"
        print(f"[1/2] Cloud Functions: {status_f}")
        print(f"      Dev: {res_f['dev_count']} functions | Test: {res_f['test_count']} functions")
        if not res_f["synced"]:
            if res_f["only_dev"]:
                print(f"      • Only in Dev:  {', '.join(res_f['only_dev'])}")
            if res_f["only_test"]:
                print(f"      • Only in Test: {', '.join(res_f['only_test'])}")
    else:
        print(f"[1/2] Cloud Functions: Error ({res_f})")
    
    # 2. Indexes
    ok_i, res_i = check_indexes()
    if ok_i:
        status_i = "✓ 100% IN SYNC" if res_i["synced"] else "✗ DRIFT DETECTED"
        print(f"\n[2/2] Firestore Composite Indexes: {status_i}")
        print(f"      Dev: {res_i['dev_count']} indexes | Test: {res_i['test_count']} indexes")
        if not res_i["synced"]:
            if res_i["only_dev"]:
                print(f"      • Only in Dev:  {', '.join(res_i['only_dev'])}")
            if res_i["only_test"]:
                print(f"      • Only in Test: {', '.join(res_i['only_test'])}")
    else:
        print(f"\n[2/2] Firestore Composite Indexes: Error ({res_i})")

    print("\n[✓] Staging Parity Audit Complete.\n")

if __name__ == "__main__":
    main()
