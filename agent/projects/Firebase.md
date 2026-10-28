# Firebase Backend Profile (Private Personal Knowledge Base)

- **Repo Scope:** `Math-Junior/Firebase`
- **Application:** Central backend for RODO agriculture-services marketplace.
- **Components:** Cloud Functions (Node 22), Firestore/Storage security rules, Realtime Database (`database.rules.json`), Firestore composite indexes, and operational scripts.

---

## 1. Codebase Architecture

Each functions codebase runs independently with its own `package.json` (Node 22):
- **`functions-core`:** Core business logic (orders, matching, payments, accounts, agent location & presence). Tests in `cd functions-core && npm test`.
- **`functions-cms`:** Endpoints dedicated to the CMS admin panel.
- **`functions-cron`:** Scheduled maintenance jobs, timeouts, automated billing routines.
- **`functions-iot`:** Telemetry and tracking ingestion for hardware / GPS devices.
- **`functions-website`:** Public website forms and lead generation.
- **`Scripts/`:** Deployment orchestration (`deploy/deploy.mjs`) and data migration scripts.

---

## 2. Environments & Safety Boundaries

| Environment | Firebase Project ID | Policy |
| :--- | :--- | :--- |
| **Dev** | `final-15ec5` | Standard development sandbox |
| **Test / Staging** | `project-agri-test-84e72` | Test environment for verifying bug fixes and band-aids |
| **Prod** | `rodo-prod0226` | **STRICTLY OFF-LIMITS.** Never deploy, write, or mutate. `--allow-prod` banned. |

- Always specify `--project project-agri-test-84e72` or `--project final-15ec5` explicitly on all CLI commands.
- Reading Prod data requires explicit, just-in-time user authorization.

---

## 3. Deployment & Rules Protocol

1. **Cloud Functions:**
   - Always run `Scripts/deploy/deploy.mjs --dry-run` first.
   - Deploy to non-prod targets:
     ```bash
     node Scripts/deploy/deploy.mjs --project test --codebases functions-core --yes
     ```
2. **Realtime Database Rules:**
   - When modifying `database.rules.json`, deploy with `--database-rules` flag.
   - Synchronize fields with `functions-core/docs/features/RTDB_LOCATION_SETTINGS.md` (e.g. `isOnline`, `isTracking`).
3. **Firestore & Storage Rules / Indexes:**
   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage --project project-agri-test-84e72
   ```
4. **Secret Hygiene:**
   - Service account keys must live outside the repository.
   - Never print, commit, or log secret keys or auth tokens.
