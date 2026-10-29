---
name: git-promotion-wizard
description: Autonomous Git promotion pipeline between Dev, Test, and Release branches. Verifies working tree cleanliness, checks commit divergence, creates PRs via GitHub CLI, handles clean merging, and keeps local branches synchronized.
---

# Git Promotion Wizard

An autonomous pipeline for promoting changes across organizational staging branches (`Dev` ➔ `Test` ➔ `Release`/`main`) in `Math-Junior` repositories (`CMS`, `Firebase`, `ProjectAgri`, `RODO-Website`).

---

## 1. Safety & Identity Invariants

* **Zero AI Attribution:** Commits, PR titles, and bodies must reflect Arun Rao Balappa. No AI badges or co-author tags.
* **Pre-flight Checks:** Working tree must be 100% clean (`git status --porcelain` empty).
* **Remote Sync:** Origin must be fetched to prevent fast-forward conflicts.

---

## 2. Usage

### Command Line
```bash
python3 ~/.agents/skills/git-promotion-wizard/scripts/promote.py \
  --repo /home/arun/Work/CMS \
  --from Dev \
  --to Test \
  --title "Promote subcollections OAuth fallback to Test" \
  --merge
```

### Dry Run
```bash
python3 ~/.agents/skills/git-promotion-wizard/scripts/promote.py \
  --repo /home/arun/Work/Firebase \
  --from Dev \
  --to Test \
  --title "Test Run" \
  --dry-run
```
