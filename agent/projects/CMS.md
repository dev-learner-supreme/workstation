# CMS Profile (Private Personal Knowledge Base)

- **Repo Scope:** `Math-Junior/CMS`
- **Application:** RODO Operations Admin Console (Next.js 16 App Router, React 18, TypeScript).
- **Authentication:** NextAuth with Google.
- **Backend:** `firebase-admin` on the server.

## Code Standards & State
- **Typing:** Strict TypeScript. Banned: `any`. Explicit interfaces for API payloads, models, and props.
- **State & Components:** Functional components only. Keep components pure and stateless; lift state up. Prefer React Server Components unless client interactivity is strictly required.
- **Modularity:** Break features into smaller reusable components and utility functions rather than monolithic files.
- **Errors:** Explicit async error handling; no empty or silent catch blocks.
- **Security:** API routes behind `middleware.ts`; strictly validate inputs.

---

## Cost & Realtime Architecture Invariants

1. **Scale-to-Zero Cloud Run Architecture:**
   - App Hosting configuration uses `minInstances: 0` in `apphosting.yaml`.
   - Tunable session keep-warm duration is stored in `/config/Instance_Settings` under `cms.duration_minutes` (default 60 min).
   - In-browser user interactions throttle activity pings to `POST /api/instance-activity`, updating `cms.last_activity_timestamp`.
   - Dynamic Cloud Scheduler job `keepCmsWarm` runs every 5 minutes and pings `GET /api/health` only while user activity is fresh.
2. **Users Table O(1) Reads:**
   - `/api/allusers` reads root `userType`, `hasAgentProfile`, and `subcollections` array from `Users/{uid}` directly.
   - Never call `listCollections()` per table row or poll the users page on an interval.
3. **Browser Firestore Notifications:**
   - Realtime order/verification notifications use scoped Firestore listeners in the browser guarded by custom claim `cms: true` (instead of Server-Sent Events streams on Cloud Run), preventing persistent 24/7 CPU allocation charges.
