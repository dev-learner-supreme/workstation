# Operational Memory & Workspace State

* **Active Machine:** Acer Swift Go 14 (`SFG14-71`, Intel Core i5-13500H, 16 GB LPDDR5, 512 GB SSD)
* **OS / Desktop:** Bare-metal Omarchy 4.0.6 (Arch Linux + Hyprland + Limine UKI)
* **Storage Layer:** Btrfs on LUKS2 with persistent `allow-discards` (TRIM active, `discard_max_bytes=2T`).
* **Hardware Permissions:** User `arun` in `uucp` (GID 984) & `dialout` for native ESP32 serial communication.
* **Power Management:** `/usr/local/sbin/cpu-power-cap` (PL1 18W / PL2 35W / tau 28s) locked to <83°C package thermal threshold.
* **Shell Architecture:** `/bin/bash` login shell for Omarchy stability; `foot` spawns `zsh` natively with size 13 JetBrainsMono Nerd Font. `SSH_AUTH_SOCK` bound to systemd user `ssh-agent.socket`.
* **Desktop Plugins:** Spaces (`tornikegomareli.spaces` pinned at `458852c`) and Pomodoro (`techywilbur.pomodoro` pinned at `475b130c`) enabled; native workspaces disabled. Cursor theme: `breeze_cursors`.
* **Mobile Toolchain (Android):** Standalone user-space install at `~/.local/share/android-studio` (AI-262.10968.63.2622.16730706) with CLI binary `~/.local/bin/studio` and launcher `~/.local/share/applications/android-studio.desktop`. User-space ownership allows internal self-updates without sudo and prevents Omarchy/pacman package drift. `ANDROID_HOME` configured to `~/Android/Sdk` in shells; `adb` active upon completing first-run wizard.
  * **Debug Keystore:** Stored at `~/.android/debug.keystore` and symlinked to `~/.config/.android/debug.keystore` for XDG AGP compatibility.
  * **SHA-1:** `E1:20:1F:CE:CB:1A:20:B6:38:D8:4A:52:7A:D0:9F:D1:D5:44:53:7C` (`e1201fcecb1a20b638d84a527ad09fd1d544537c`)
  * **SHA-256:** `E8:66:49:80:AE:BF:E6:32:38:C1:CE:B9:82:DC:FC:CB:6B:5E:6A:0D:E8:90:16:99:85:4A:3F:66:0C:B5:AF:72` (`e8664980aebfe63238c1ceb982dcfccb6b5e6a0de8901699854a3f660cb5af72`)
  * **Firebase Registration:** Added to Dev (`final-15ec5`) and Test (`project-agri-test-84e72`). Updated `google-services.json` downloaded into `app/src/dev/` and `app/src/staging/`.
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
