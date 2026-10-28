# Agent Customization & Memory Manifest

This directory (`~/.agents/`) is the centralized configuration hub for AI coding assistants (Google Antigravity, Claude Code, Cursor, GitHub Copilot) in this environment.

---

## Directory Structure

```text
~/.agents/
├── README.md               # This manifest
├── AGENTS.md               # Master ruleset, instructions, boundaries & protocols
├── MEMORY.md               # Dynamic operational memory, active workflows & task state
├── SYSTEM_CAPABILITIES.md  # Dynamic inventory of installed Omarchy packages & developer runtimes
├── sync.sh                 # Upstream git synchronization script (sync-agent alias)
├── projects/               # Private project profiles (ProjectAgri, CMS, RODO-Website, Firebase, HWCode)
├── rules/
│   └── AGENTS.md           # Symlink -> ../AGENTS.md (for engines discovering .agents/rules/*.md)
└── skills/                 # On-demand modular workflows (loaded progressively)
    ├── esp32-hardware/     # Native ESP32 serial communication & flashing on Linux (/dev/ttyUSB0)
    ├── real-user-testing/  # End-to-end testing SOP for ProjectAgri mobile app & CMS
    ├── omarchy-resource-guard/ # CPU thermal capping, zram, and disk resource bounds
    ├── agent-self-tuning/  # Loop circuit breaker, token waste auditing, and meta-learning
    ├── omarchy-health/     # Diagnostics for Omarchy shell, Hyprland, and audio routing
    ├── thermal-watch/      # Real-time RAPL power package telemetry and throttling monitor
    └── agent-health-check/ # Deterministic diagnostic engine (scripts/doctor.sh)
```

---

## 1. Rules, Instructions & Memory (`AGENTS.md`)

- **Canonical File:** `~/.agents/AGENTS.md`
- **Root Symlinks:**
  - `~/AGENTS.md` -> `~/.agents/AGENTS.md`
  - `~/GEMINI.md` -> `~/.agents/AGENTS.md`
  - `~/CLAUDE.md` -> `~/.agents/AGENTS.md`
  - `~/.cursorrules` -> `~/.agents/AGENTS.md`
- **Scope:**
  1. **Environment Boundaries:** Prod (`rodo-prod0226`) strictly off-limits without explicit consent; Dev (`final-15ec5`); Staging/Test (`project-agri-test-84e72`).
  2. **Authorship & Attribution:** Zero AI attribution. All commits, PRs, and changes attributed solely to Arun Rao Balappa.
  3. **Omarchy Hardware Boundaries:** Hardware profile (Acer Swift Go 14, 16 GB DDR5, i5-13500H). RAPL PL1 18W/PL2 35W CPU power capping (<83°C) and native zram memory pool.
  4. **Testing Methodology:** Drive genuine UI user paths without state shortcuts.
  5. **Operational Memory & Pending Tasks:** Stored parameters and keys in `MEMORY.md`.
  6. **Hardware & Embedded Development:** Native ESP32 serial access (`uucp` group, `/dev/ttyUSB0`).
  7. **Speed, Privacy & Output Precision:** Zero pleasantries/filler, strict secret omission, targeted function/class edits only.
  8. **Continuous Self-Improvement & Efficiency Loop:** Anti-loop circuit breaker (max 2 failed attempts before diagnosing), context hygiene, and immediate rule persistence.
  9. **Persona & Communication Protocol (J.A.R.V.I.S. Mode):** Composed, technically authoritative, structured outputs, proactive risk analysis, zero playful banter or conversational filler. 100-steps-ahead anticipation.

---

## 2. On-Demand Skills (`skills/`)

Skills follow the progressive disclosure model: only the name and description are in the context window until triggered or explicitly invoked.

| Skill | Description | Location |
| :--- | :--- | :--- |
| **`agent-health-check`** | Deterministic diagnostic engine auditing toolchains, rule budgets, memory thresholds, privacy airgap, and hardware headroom. | [`skills/agent-health-check/SKILL.md`](skills/agent-health-check/SKILL.md) |
| **`agent-self-tuning`** | Protocol for detecting reasoning loops, auditing token waste, and persisting new learnings into rules. | [`skills/agent-self-tuning/SKILL.md`](skills/agent-self-tuning/SKILL.md) |
| **`esp32-hardware`** | Native procedures to verify (`/dev/ttyUSB0`) and flash ESP32 microcontrollers on Omarchy Linux. | [`skills/esp32-hardware/SKILL.md`](skills/esp32-hardware/SKILL.md) |
| **`omarchy-health`** | Deep diagnostics for Omarchy Hyprland environment, audio sinks, and display scaling. | [`skills/omarchy-health/SKILL.md`](skills/omarchy-health/SKILL.md) |
| **`omarchy-resource-guard`** | Memory, thermal, and disk safeguards to prevent throttling on the Acer Swift Go 14 laptop during Gradle/Next.js builds. | [`skills/omarchy-resource-guard/SKILL.md`](skills/omarchy-resource-guard/SKILL.md) |
| **`real-user-testing`** | SOP for driving end-to-end testing through real user UI paths on Android (`ProjectAgri`) and CMS instead of database shortcuts. | [`skills/real-user-testing/SKILL.md`](skills/real-user-testing/SKILL.md) |
| **`thermal-watch`** | Real-time monitoring of Intel RAPL power limits, package wattage, and thermal headroom. | [`skills/thermal-watch/SKILL.md`](skills/thermal-watch/SKILL.md) |
