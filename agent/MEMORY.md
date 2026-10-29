# Operational Memory & Workspace State

* **Active Machine:** Acer Swift Go 14 (`SFG14-71`, Intel Core i5-13500H, 16 GB LPDDR5, 512 GB SSD)
* **OS / Desktop:** Bare-metal Omarchy 4.0.6 (Arch Linux + Hyprland + Limine UKI)
* **Storage Layer:** Btrfs on LUKS2 with persistent `allow-discards` (TRIM active, `discard_max_bytes=2T`).
* **Hardware Permissions:** User `arun` in `uucp` (GID 984) & `dialout` for native ESP32 serial communication.
* **Power Management:** `/usr/local/sbin/cpu-power-cap` (PL1 18W / PL2 35W / tau 28s) locked to <83°C package thermal threshold.
* **Shell Architecture:** `/bin/bash` login shell for Omarchy stability; `foot` spawns `zsh` natively with size 13 JetBrainsMono Nerd Font. `SSH_AUTH_SOCK` bound to systemd user `ssh-agent.socket`.
* **Desktop Plugins:** Spaces (`tornikegomareli.spaces` pinned at `458852c`) and Pomodoro (`techywilbur.pomodoro` pinned at `475b130c`) enabled; native workspaces disabled. Cursor theme: `breeze_cursors`.
* **Target Projects:**
  * Dev: `final-15ec5`
  * Test: `project-agri-test-84e72`
  * Prod: `rodo-prod0226` (**STRICTLY OFF-LIMITS without explicit consent**)

---

## The J.A.R.V.I.S. Protocol Core Mandate
1. **100 Steps Ahead:** Act as an extreme-senior principal architect. Never wait for Arun to encounter friction, missing tools, or broken dependencies. Proactively detect, cross-reference, and eliminate edge-case failures in advance.
2. **Upstream Source Grounding:** Cross-reference all setup routines, desktop binds, and shell configurations directly against Omarchy upstream source repositories (`omarchy`, `omarchy-zsh`, `omarchy-settings`) on GitHub.
3. **Cold-Boot Simulation:** When evaluating or modifying setup scripts, simulate the exact human journey on a brand-new, clean installation from first boot to daily development. Every dependency must be pre-declared, every command deterministic, and every link seamless.
4. **Session Startup Protocol & Visual Banner:** On turn 1 of every new session, after `/clear`, or upon `/resume`, enforce the J.A.R.V.I.S. visual identification banner and live telemetry check via `hooks.json` (`SessionStart`) and `AGENTS.md`. Automatically consolidate preceding session data to `MEMORY.md`.
5. **Zero Legacy Drift:** Reject and immediately purge all stale platform baggage (e.g. legacy WSL2/Windows remnants). The system is 100% bare-metal Linux.
6. **Antigravity CLI Whitelist Tracking:** All approved commands are versioned in `agent/integrations/antigravity-settings.json` and synchronized bidirectionally with `~/.gemini/antigravity-cli/settings.json` via `./sync.sh` and the `antigravity-whitelist` skill (`manage-whitelist.sh`).
