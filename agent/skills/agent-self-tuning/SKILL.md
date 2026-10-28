---
name: agent-self-tuning
description: Framework for analyzing conversation efficiency, token consumption, and debugging loops. Used to self-correct during sessions and persist operational learnings into workspace rules and skills.
---

# Agent Self-Tuning & Continuous Optimization

A structured protocol for auditing agent efficiency, diagnosing token waste, halting circular troubleshooting, and continuously updating workspace rules and memory.

---

## 1. Circuit Breaker for Debugging Loops

When troubleshooting a bug, build error, or environment issue:

1. **Failure Count Threshold:**
   - Attempt 1: Apply the most probable, evidence-backed fix.
   - Attempt 2: If Attempt 1 fails, formulate a distinct alternative hypothesis based on the new error output.
   - **Attempt 3 is BLOCKED:** Never blindly guess a 3rd time.
2. **Circuit Breaker Action:**
   - Run diagnostic commands (read exact config, verify versions, inspect logs directly).
   - Re-read relevant repo documentation or source declarations.
   - State the discrepancy clearly to the user in 2-3 bullet points rather than burning cycles running blind permutations.

---

## 2. Token & Latency Waste Audit

Always watch for and eliminate these 4 common token drains:

| Waste Pattern | Bad Practice | Optimized Approach |
| :--- | :--- | :--- |
| **Unbounded Reads** | Reading entire 1,000+ line files | Read only relevant line ranges (`StartLine`/`EndLine`). |
| **Noisy Shell Output** | Running `find`, `npm list`, or `logcat` raw | Filter or truncate: `command \| head -n 30` or `grep -E`. |
| **Conversational Filler** | Explaining code changes with paragraphs | Use brief inline comments in the code and diffs only. |
| **Redundant Re-Search** | Re-discovering the same file structure across turns | Anchor the structure in the repo's `AGENTS.md` or a skill. |

---

## 3. The Continuous Improvement & Governance Protocol

Whenever a task reveals a friction point, non-obvious setup detail, or user preference:

1. **Governance & Autonomy Tiers (Separate Learning from Policy Change):**

   | Change Type | Autonomy Level | Target Location |
   | :--- | :--- | :--- |
   | **Operational Facts & Transient State** | Automatic update with dates & evidence | `~/.agents/MEMORY.md` |
   | **Reusable Skills & Procedures** | Propose focused change, validate against incident, version | `~/.agents/skills/` |
   | **Global Rules & Safety Boundaries** | Require explicit confirmation before altering governing policy | `~/.agents/AGENTS.md` |
   | **Command Permissions & Security Access** | Require threat-model review & explicit user authorization | `settings.json` / Whitelist |

2. **Identify the Learning:**
   - E.g.: "Device X requires a specific udev rule", "Gradle task requires in-process compiler", "API endpoint expects snake_case payloads".
3. **Select the Right Tier:**
   - **Global (`~/.agents/AGENTS.md`):** Cross-cutting behaviors, machine resource caps, user attribution, safety.
   - **Repository (`<repo>/AGENTS.md`):** Framework constraints, architecture patterns (MVVM, NextAuth), environment endpoints.
   - **Skill (`~/.agents/skills/<name>/SKILL.md`):** Multi-step manual workflows or domain procedures (e.g. flashing microcontrollers, running complex E2E tests).
4. **Persist & Verify:**
   - Edit the appropriate target file during the session. Do not defer or leave it in conversational memory, which evaporates when the session ends.
   - Verify that the updated procedure eliminates friction without introducing contradictory policies.

---

## 4. Interactive Correction Protocol (`/learn`)

When Arun corrects a technical assumption, library choice, or code pattern:

1. **Acknowledge Instantly:** Confirm the correction in one direct sentence without apologies or conversational fluff.
2. **Execute the Fix:** Apply the corrected logic immediately to the active file.
3. **Persist the Learning:**
   - Write the new rule into the active repository's `AGENTS.md` or update [`~/.agents/MEMORY.md`](file:///home/arun/.agents/MEMORY.md).
   - Never let a valid user correction be forgotten across session boundaries.
4. **Trigger Auto-Sync:**
   - If changes were written to `~/.agents/`, automatically run [`~/.agents/sync.sh`](file:///home/arun/.agents/sync.sh) to ensure remote backup.

---

## 5. Automated Upstream Synchronization

Whenever rule files, operational memory, or skills inside `~/.agents/` are modified:
- Trigger [`~/.agents/sync.sh`](file:///home/arun/.agents/sync.sh).
- Stage all changes, commit under author `Arun Rao Balappa`, and push to `origin main`.
- If in a sandboxed session where network push is delayed, ensure local commit succeeds so no work is lost on exit.

---

## 6. Safe Pruning & Memory Consolidation

To prevent rule bloat while preserving critical knowledge:

1. **Trigger Condition:** Audit file length when `MEMORY.md` exceeds 250 lines or conversation rules approach context budgets.
2. **Pruning Rules:**
   - **Delete:** Completed PR states, merged branch temporary notes, resolved debugging trails.
   - **Compress:** Multi-paragraph explanations -> single dense constraint bullet.
   - **Never Touch:** Safety boundaries (Prod isolation, zero AI attribution), active task keys, hardware pinouts, and OEM background execution quirks.

---

## 7. Organization Repository Airgap

- **Boundary Mandate:** Private agent configurations (`~/.agents/`, `.cursorrules`, `CLAUDE.md`, `MEMORY.md`) must NEVER enter shared repositories (`Math-Junior/ProjectAgri`, `Math-Junior/CMS`, `Math-Junior/RODO-Website`, `Math-Junior/HWCode`).
- **Storage:** Repo-specific personal knowledge is archived strictly in `~/.agents/projects/`.
- **Enforcement:** Global gitignore at `~/.gitignore_global` guarantees that git commands inside project trees ignore personal agent artifacts.
