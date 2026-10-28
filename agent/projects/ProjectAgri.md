# ProjectAgri Profile (Private Personal Knowledge Base)

- **Repo Scope:** `Math-Junior/ProjectAgri`
- **Application:** RODO Android app (`in.co.rodo`, minSdk 29, targetSdk 36).
- **Flavors:**
  - `dev`: `in.co.rodo.dev` -> Firebase `final-15ec5`
  - `staging`: `in.co.rodo.staging` -> Firebase `project-agri-test-84e72`
  - `prod`: `in.co.rodo` -> Firebase `rodo-prod0226` (READ-ONLY, strictly off-limits for writes)

## Architecture & Code Accuracy
- **Language:** Kotlin only. Banned: Java for new files.
- **UI:** Jetpack Compose for all new UI. Banned: XML layouts and synthetic bindings.
- **Architecture:** Strict MVVM. UI observes state via `StateFlow` or `LiveData`.
- **Async:** Kotlin Coroutines exclusively. Banned: `AsyncTask` and RxJava.
- **Testing:** Verify end-to-end through real user paths (Profile, duty toggle, settings). Test background location services on real physical devices (Xiaomi, Samsung) to account for aggressive OEM process killing.
