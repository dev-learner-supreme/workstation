---
name: staging-parity-check
description: Deterministic parity audit between Dev (final-15ec5) and Test (project-agri-test-84e72). Audits Gen2 Cloud Functions, Firestore composite indexes, security rules, and config collections.
---

# Staging Parity Auditor

Deterministic audit tool verifying parity across staging environments:
* **Dev Project:** `final-15ec5`
* **Test Project:** `project-agri-test-84e72`

---

## 1. Scope & Verification Vectors

1. **Cloud Functions (Gen2):**
   - Asserts exact name & count match across Dev and Test.
   - Detects orphaned or unpromoted functions.
2. **Firestore Composite Indexes:**
   - Compares collection groups and indexed field paths across environments.
3. **Firestore `/config` Documents:**
   - Validates that environment configurations match and identifies orphaned collection documents.

---

## 2. Usage

### On-Demand CLI Audit
```bash
python3 ~/.agents/skills/staging-parity-check/scripts/check_parity.py
```

### Direct Slash Command
In Antigravity CLI, invoke `/staging-parity-check` to run an immediate automated verification.
