---
name: thermal-watch
description: Check thermals, CPU power cap, throttling, power profile and battery on the user's Acer Swift Go 14 (Omarchy), compare against earlier runs, and say whether anything should be tuned or left alone. Use when the user runs /thermal-watch or asks how the laptop's temperatures, power cap, fans/heat or throttling are doing.
---

# Thermal watch

Read-only health check of the thermal and power changes made on this laptop
(Acer Swift Go 14 SFG14-71, i5-13500H, Omarchy). Gather data, interpret it
against the baselines below, then give a short verdict: **leave as is**, or
**specific fixes** with reasons. Never change settings without asking first.

## 1. Collect

```bash
~/.claude/skills/thermal-watch/thermal-watch.sh            # quick report (<1 s)
~/.claude/skills/thermal-watch/thermal-watch.sh --load 240 # + all-core load test
```

Run the quick report by default. Only run `--load` when the user asks for a
stress or load test, or agrees to one after you suggest it (it takes about 5 min
and the fans get loud). Use a Bash timeout of at least `(N + 120) * 1000` ms.

Also read the memory file `laptop-thermals.md` for earlier verdicts and numbers.

## 2. What was changed (so you know what to verify)

- **Power cap**: `/etc/default/cpu-power-cap` (PL1_W / PL2_W / TAU_S, currently
  18 / 35 / 28). `/usr/local/sbin/cpu-power-cap` writes both RAPL zones,
  `intel-rapl:0` (MSR) and `intel-rapl-mmio:0`; the hardware enforces the
  lower of the two. `cpu-power-cap.timer` re-applies the values every 60 s and
  logs each correction (`journalctl -t cpu-power-cap`).
- **Logger**: `cpu-power-stats.timer` (root) appends one row per minute to
  `/var/log/cpu-power-stats.csv`. Columns: time, pkg_w (1-min average),
  pkg_temp_c, tcpu_c, PL1/PL2 for MSR and MMIO, pkg_throttle_count/ms, ac,
  bat_w, freq_mhz, epp, load1. It keeps about 14 days. Package power is
  root-only by design (RAPL side channel), which is why this logger exists.
  Don't make `energy_uj` world-readable.
- **thermald** runs `--adaptive`, using the Acer DPTF/GDDV table. It is kept on
  as a safety net. It rewrites the MMIO PL1 and tau during the first few
  minutes after boot, and the timer puts them back.
- **power-profiles-daemon** is managed by Omarchy: `omarchy-powerprofiles-set`
  picks **performance on AC** unless the user saved a preference
  (`~/.local/state/omarchy/powerprofiles/{ac,battery}`). The Omarchy way to
  change it is `omarchy-powerprofiles-set ac balanced` (it remembers the
  choice).

## 3. Baselines and how to read the report

Hardware facts (measured on Ubuntu, 2026-10-11): the cooling saturates at about
**22 W at ~92 °C**, and **18 W is about 83 °C** under full load. Reviews show
about 43 W for this model on Windows, so the cooler is likely degraded (dust or
paste). Linux has no fan control on this model, and undervolting is blocked.

| Signal | Fine | Act on it |
|---|---|---|
| Limits vs config | MSR and MMIO both match `/etc/default/cpu-power-cap` | Mismatch → timer broken. Check `systemctl status cpu-power-cap.timer` |
| Corrections | Only in the first ~10 min of each boot, on MMIO | MSR corrections, or regular ones late in a boot → thermald is fighting. Report how often. If more than about 1/hour, consider a thermald config, or dropping `--adaptive` (tradeoff: weaker DPTF protection) |
| Idle (load1 < 1) | pkg ≤ 55 °C, pkg_w ≤ 5 W | Higher → check top processes and EPP. `performance` EPP on AC raises idle power and heat |
| Sustained load (rows at PL1) | avg temp ≤ 85 °C | ≥ 90 °C or throttle count climbing → lower PL1 by 2 W, or clean the vents/repaste |
| Headroom | Long load at PL1 sits at ≤ 78 °C | Could try PL1 20 W, then re-run `--load` and compare |
| Throttle count | Flat during normal use. Short bursts at boot/install with PL2 35 W are normal | Rising steadily in normal use → thermal limit reached. Consider PL2 30 W or the balanced profile |
| Battery | Health drifts slowly (88 % at 209 cycles on 2026-10-21) | Sudden drop, or no charge limit wanted → mention it. This model has no `charge_control_end_threshold` |

Weigh the history over the live snapshot: one spike while installing packages
is not a problem. Note how much data there is ("4 samples" isn't a trend; a
week is).

## 4. Report back

- 3–6 bullet verdict: what's healthy and what's not, with the numbers.
- For each suggested fix: the exact command, whether it needs root
  (`pkexec`/`sudo`), the tradeoff, and how to verify it with the next run.
- If nothing needs changing, say so plainly and recommend leaving it.
- Append one dated line to the memory file `laptop-thermals.md` with the key
  numbers (idle temp, sustained-load temp and power, late corrections per boot,
  throttle trend, battery health), so later runs can compare trends.
