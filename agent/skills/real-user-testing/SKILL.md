---
name: real-user-testing
description: Standard operating procedure for verifying mobile app (ProjectAgri) and CMS features through genuine user UI paths end-to-end.
---

# Real User Testing Runbook

When testing features and bug fixes across the RODO ecosystem (especially the `ProjectAgri` Android app and `CMS` admin console), always verify via real user paths.

## Key Principles

1. **Drive Genuine UI Paths End-to-End:**
   - Follow every step a farmer or worker agent would experience on the real device.
   - For multi-step flows, start with prerequisites missing and progress through every dialog, permission prompt, and confirmation screen to the end.
   - Switch languages, toggle duty states, or change roles via the UI itself (e.g. Profile screen language selector).

2. **No State Shortcuts:**
   - Do NOT edit SharedPreferences or databases directly via `run-as` to fake a completed onboarding, registration, or state transition.
   - Use `adb`, `pm`, or database edits **only** to establish test preconditions (e.g., revoking a runtime permission or toggling network/location off to test failure recovery).

3. **Verify Against the Correct Target:**
   - Always run verification against **Dev (`final-15ec5`)** or **Test (`project-agri-test-84e72`)**.
   - **Never run test mutations or write verification scripts against Prod (`rodo-prod0226`).**
