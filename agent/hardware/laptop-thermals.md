---
name: laptop-thermals
description: Acer Swift Go 14 SFG14-71 cooling limits measured 2026-10-11 (saturates ~22W at 92°C) and what can't be done on it
metadata:
  type: project
---

Measured on Ubuntu 2026-10-11, all cores loaded, plugged in: cap 28→22.9W 92°C | 24→22.2W 91°C | 20→20W 88°C | 17→17W 80°C | 14→14W 72°C. Cooling saturates at about 22W near TjMax-8; reviews show ~43W at 89°C for this model, so likely a hardware cooling issue (vents, dust or paste). The user settled on PL1 18W / PL2 35W / tau 28s (~83°C). Re-installed on [[system-omarchy]] 2026-10-21: `/etc/default/cpu-power-cap` (PL1_W/PL2_W/TAU_S), `/usr/local/sbin/cpu-power-cap` caps both intel-rapl:0 (MSR) and intel-rapl-mmio:0, run by `cpu-power-cap.service` + a 60s `cpu-power-cap.timer`; corrections log via `journalctl -t cpu-power-cap`. BIOS defaults were PL1 45W, PL2 82W (MSR)/64W (MMIO). thermald --adaptive kept.

BIOS V1.10 is the latest (checked 2026-10-11); fwupd/LVFS has no Acer BIOS, so updating needs Hiren's BootCD PE + Acer .exe.

**Why:** the user wants a cool laptop with a set-once-and-forget setup.
**How to apply:** if thermals come up again, start from these numbers. Linux has no fan control here (Acer WMI thermal modes are unsupported on Swift); don't suggest Linuwu-Sense, throttled or undervolting (blocked by Secure Boot or unsupported). Note thermald on this machine rewrites MSR PL1/PL2 on start, so any cap needs a watchdog. Heavy workload: Android Studio + emulator + Gradle + Firefox.

Monitoring (2026-10-21): skill `thermal-watch` (`~/.claude/skills/thermal-watch/`, report script `thermal-watch.sh [--load N]`) plus root logger `cpu-power-stats.timer` → `/var/log/cpu-power-stats.csv` (1-min rows, ~14 days). Append a dated line below after each run.
- 2026-10-21 (first run, 16 min uptime, AC): idle pkg ~55-62°C, ~5 W; profile/EPP = performance (Omarchy's AC default, no saved preference); 843 package throttle events since boot (install bursts at PL2 35 W); cap holds on both zones; late corrections 0; battery 88.0% @ 209 cycles.
- 2026-10-21 (later): user saved AC profile as balanced (`omarchy-powerprofiles-set ac balanced`); EPP now balance_performance on AC. Omarchy's default on AC is performance unless a preference is saved in `~/.local/state/omarchy/powerprofiles/ac`.
- 2026-10-21 (via omarchy-health, 2h43m uptime, AC, balanced): 143 logger rows; pkg median 3.5 W / p95 6.2 W, temp median 50°C / p95 61°C, one minute ≥85°C, 0 min at PL1; cap 18/35 W holds on both zones; 12 corrections this boot, all in the first 10 min (thermald); 1053 throttle events, from short PL2 bursts. Verdict: leave as is.
- 2026-10-26 (Day 5, via omarchy-health, 5d 1h uptime, Battery, balanced): 2780 logger rows; pkg power median 3.1 W / p95 6.6 W, temp median 47°C / p95 57°C, live pkg 49-50°C, NVMe 33°C; cap 18/35 W holds on MSR/MMIO; battery 86% @ 95.3% health / 214 cycles. Verdict: leave as is.
