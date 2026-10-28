# Agent Customization & Memory Manifest

This directory (`~/.agents/`) is the centralized configuration hub for AI coding assistants (Google Antigravity, Claude Code, Cursor, GitHub Copilot) in this environment.

---

## Directory Structure

```text
~/.agents/
├── README.md               # This manifest
├── AGENTS.md               # Master ruleset, instructions, boundaries & protocols
├── MEMORY.md               # Dynamic operational memory, active workflows & task state
├── SYSTEM_CAPABILITIES.md  # Dynamic inventory of installed WSL packages & developer runtimes
├── sync.sh                 # Upstream git synchronization script (sync-agent alias)
├── projects/               # Private project profiles (ProjectAgri, CMS, RODO-Website, Firebase, HWCode)
├── rules/
│   └── AGENTS.md           # Symlink -> ../AGENTS.md (for engines discovering .agents/rules/*.md)
└── skills/                 # On-demand modular workflows (loaded progressively)
    ├── esp32-wsl-hardware/ # ESP32 usbipd binding, attachment, and serial flashing in WSL2
    ├── real-user-testing/  # End-to-end testing SOP for ProjectAgri mobile app & CMS
    ├── wsl-resource-guard/ # CPU, RAM & disk resource caps for Acer Swift Go 14 laptop
    ├── agent-self-tuning/  # Loop circuit breaker, token waste auditing, and meta-learning
    └── agent-health-check/ # Deterministic 21-point diagnostic engine (scripts/doctor.sh)
```

---

## 1. Rules, Instructions & Memory (`AGENTS.md`)

- **Canonical File:** `~/.agents/AGENTS.md`
- **Root Symlinks:**
  - `~/AGENTS.md` -> `~/.agents/AGENTS.md`
  - `~/GEMINI.md` -> `AGENTS.md`
- **Scope:**
  1. **Environment Boundaries:** Prod (`rodo-prod0226`) strictly off-limits without explicit consent; Dev (`final-15ec5`); Staging/Test (`project-agri-test-84e72`).
  2. **Authorship & Attribution:** Zero AI attribution. All commits, PRs, and changes attributed solely to Arun Rao Balappa.
  3. **WSL2 Resource Constraints:** Hardware profile (Acer Swift Go 14, 16 GB DDR5, i5-13500H). Memory bounds on Gradle & Node.js builds.
  4. **Testing Methodology:** Drive genuine UI user paths without state shortcuts.
  5. **Operational Memory & Pending Tasks:** Stored parameters and keys (e.g. local debug SHA-1/SHA-256 for `in.co.rodo`).
  6. **Hardware & Embedded Development:** ESP32 connection procedure and port management.
  7. **Speed, Privacy & Output Precision:** Zero pleasantries/filler, strict secret omission, targeted function/class edits only.
  8. **Continuous Self-Improvement & Efficiency Loop:** Anti-loop circuit breaker (max 2 failed attempts before diagnosing), context hygiene, and immediate rule persistence.
  9. **Persona & Communication Protocol (J.A.R.V.I.S. Mode):** Composed, technically authoritative, structured outputs, proactive risk analysis, zero playful banter or conversational filler.

---

## 2. On-Demand Skills (`skills/`)

Skills follow the progressive disclosure model: only the name and description are in the context window until triggered or explicitly invoked.

| Skill | Description | Location |
| :--- | :--- | :--- |
| **`agent-health-check`** | Deterministic 21-point diagnostic engine auditing toolchains, rule budgets, memory thresholds, privacy airgap, and WSL2 headroom. | [`skills/agent-health-check/SKILL.md`](skills/agent-health-check/SKILL.md) |
| **`agent-self-tuning`** | Protocol for detecting reasoning loops, auditing token waste, and persisting new learnings into rules. | [`skills/agent-self-tuning/SKILL.md`](skills/agent-self-tuning/SKILL.md) |
| **`esp32-wsl-hardware`** | Step-by-step procedures to bind, attach, verify (`/dev/ttyUSB0`), and flash ESP32 microcontrollers in WSL2 via Windows `usbipd-win`. | [`skills/esp32-wsl-hardware/SKILL.md`](skills/esp32-wsl-hardware/SKILL.md) |
| **`real-user-testing`** | SOP for driving end-to-end testing through real user UI paths on Android (`ProjectAgri`) and CMS instead of database shortcuts. | [`skills/real-user-testing/SKILL.md`](skills/real-user-testing/SKILL.md) |
| **`wsl-resource-guard`** | Memory, thermal, and disk safeguards to prevent WSL2 freezes on the Acer Swift Go 14 laptop during Gradle/Next.js builds. | [`skills/wsl-resource-guard/SKILL.md`](skills/wsl-resource-guard/SKILL.md) |
