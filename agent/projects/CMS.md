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
