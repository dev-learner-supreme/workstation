---
name: firebase-deploy-safe
description: Deterministic, isolated Cloud Functions deployment tool. Blocks unauthorized Prod deploys, isolates deployments by codebase to prevent namespace collisions, and runs pre-flight unit tests.
---

# Firebase Safe Deployer

A hardened deployment utility for `Math-Junior/Firebase` ensuring zero-risk deployments across environments.

---

## 1. Safety Guarantees

1. **Production Airgap:** Rejects all deploy requests targeting `rodo-prod0226` unless explicitly confirmed.
2. **Namespace Collision Prevention:** Deploys explicitly by codebase (`functions-core`, `functions-cron`, `functions-cms`, `functions-website`) to avoid conflicts where functions share names across different directories.
3. **Pre-flight Testing:** Automatically runs the test suite (`npm test`) in `functions-core` before allowing any function from that codebase to deploy.

---

## 2. Usage

### Deploying Specific Functions in a Codebase
```bash
python3 ~/.agents/skills/firebase-deploy-safe/scripts/deploy_safe.py \
  --project final-15ec5 \
  --codebase functions-core \
  --only initializeNewUser,createFarmTransaction
```

### Deploying an Entire Codebase
```bash
python3 ~/.agents/skills/firebase-deploy-safe/scripts/deploy_safe.py \
  --project project-agri-test-84e72 \
  --codebase functions-cms
```
