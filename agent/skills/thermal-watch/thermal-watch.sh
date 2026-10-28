#!/bin/bash
# Thermal / power-cap report for the Acer Swift Go 14 (SFG14-71) on Omarchy.
# Read-only, no root. Usage: thermal-watch.sh [--load SECONDS]
#   --load N   also run an N-second all-core load test (N >= 180 recommended,
#              so the per-minute logger captures package power at the cap)
set -u
LOG=/var/log/cpu-power-stats.csv
CONF=/etc/default/cpu-power-cap
MSR=/sys/class/powercap/intel-rapl:0
MMIO=/sys/class/powercap/intel-rapl-mmio:0
load_s=0
[[ ${1:-} == --load ]] && load_s=${2:-180}

w() { awk '{printf "%g", $1/1000000}' "$1" 2>/dev/null; }
zone() { for z in /sys/class/thermal/thermal_zone*; do [[ $(<"$z/type") == "$1" ]] && awk '{printf "%.0f", $1/1000}' "$z/temp"; done; }
section() { printf '\n=== %s ===\n' "$1"; }

section "Report $(date -Iseconds) | uptime $(uptime -p) | kernel $(uname -r) | omarchy $(omarchy version 2>/dev/null)"

section "Power cap: config vs actual"
cat "$CONF" 2>/dev/null | tr '\n' ' '; echo
printf 'MSR : PL1 %sW  PL2 %sW  tau %ss\n' "$(w $MSR/constraint_0_power_limit_uw)" "$(w $MSR/constraint_1_power_limit_uw)" "$(w $MSR/constraint_0_time_window_us)"
printf 'MMIO: PL1 %sW  PL2 %sW  tau %ss\n' "$(w $MMIO/constraint_0_power_limit_uw)" "$(w $MMIO/constraint_1_power_limit_uw)" "$(w $MMIO/constraint_0_time_window_us)"
for u in cpu-power-cap.timer cpu-power-stats.timer thermald.service power-profiles-daemon.service intel_lpmd.service; do
  printf '%-30s %s / %s\n' "$u" "$(systemctl is-enabled $u 2>/dev/null)" "$(systemctl is-active $u 2>/dev/null)"
done

section "Cap corrections (something overrode the limits) per boot, last 10 boots"
journalctl --list-boots --no-pager -q 2>/dev/null | tail -10 | while read -r idx _ _ start _; do
  n=$(journalctl -b "$idx" -t cpu-power-cap --no-pager -q 2>/dev/null | grep -c ' set ')
  bt=$(journalctl -b "$idx" -o short-unix --no-pager -q 2>/dev/null | head -1 | cut -d. -f1)
  late=$(journalctl -b "$idx" -t cpu-power-cap -o short-unix --no-pager -q 2>/dev/null | grep ' set ' \
    | awk -v bt="$bt" '{ split($1, a, "."); if (a[1] - bt > 600) c++ } END { print c + 0 }')
  msr_late=$(journalctl -b "$idx" -t cpu-power-cap -o short-unix --no-pager -q 2>/dev/null | grep ' set .*intel-rapl:0/' \
    | awk -v bt="$bt" '{ split($1, a, "."); if (a[1] - bt > 600) c++ } END { print c + 0 }')
  printf 'boot %4s (%s): %3s corrections, %3s after first 10 min (%s on MSR)\n' "$idx" "$start" "$n" "$late" "$msr_late"
done
echo "Last 5 corrections:"; journalctl -t cpu-power-cap --no-pager -q -o short-iso 2>/dev/null | grep ' set ' | tail -5
echo "thermald warnings/errors this boot:"; journalctl -b -u thermald -p 4 --no-pager -q 2>/dev/null | tail -5 || true

section "Live snapshot"
printf 'pkg %s°C | TCPU_PCI %s°C | SEN2 %s°C | SEN3 %s°C\n' "$(zone x86_pkg_temp)" "$(zone TCPU_PCI)" "$(zone SEN2)" "$(zone SEN3)"
sensors 2>/dev/null | grep -iE '^(Package|Core|Composite|nvme|edge)' | head -12
printf 'profile %s | EPP %s | avg freq %s MHz | load %s\n' "$(powerprofilesctl get 2>/dev/null)" \
  "$(</sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)" \
  "$(awk '{ s += $1; n++ } END { printf "%.0f", s / n / 1000 }' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq)" \
  "$(cut -d' ' -f1-3 /proc/loadavg)"
echo "Omarchy saved profiles: ac=$(cat ~/.local/state/omarchy/powerprofiles/ac 2>/dev/null || echo default-performance) battery=$(cat ~/.local/state/omarchy/powerprofiles/battery 2>/dev/null || echo default-balanced)"
tt=/sys/devices/system/cpu/cpu0/thermal_throttle
echo "throttle since boot: package $(<$tt/package_throttle_count) events / $(<$tt/package_throttle_total_time_ms) ms, core0 $(<$tt/core_throttle_count) events"
for p in /sys/class/power_supply/*; do
  [[ $(<"$p/type") == Mains ]] && echo "AC online: $(<"$p/online")"
done
for p in /sys/class/power_supply/BAT*; do
  kind=energy; [[ -r $p/energy_full ]] || kind=charge
  [[ -r $p/${kind}_full && -r $p/${kind}_full_design ]] || continue
  awk -v n="${p##*/}" -v s="$(<"$p/status")" -v cyc="$(cat "$p/cycle_count" 2>/dev/null)" -v f="$(<"$p/${kind}_full")" -v d="$(<"$p/${kind}_full_design")" \
    'BEGIN { printf "%s: %s, health %.1f%% (full %d / design %d), cycles %s\n", n, s, f * 100 / d, f, d, cyc }'
done
echo "Top CPU users:"; ps -eo pcpu,comm --sort=-pcpu | sed -n 2,6p

if ((load_s > 0)); then
  section "Load test: $load_s s on all $(nproc) threads (fans will spin up)"
  start=$(date +%s); pids=()
  for _ in $(seq "$(nproc)"); do yes >/dev/null & pids+=($!); done
  trap 'kill ${pids[*]} 2>/dev/null' EXIT
  t0=$(<$tt/package_throttle_count)
  while (( $(date +%s) - start < load_s )); do
    printf 't+%3ss pkg %s°C freq %s MHz\n' "$(( $(date +%s) - start ))" "$(zone x86_pkg_temp)" \
      "$(awk '{ s += $1; n++ } END { printf "%.0f", s / n / 1000 }' /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq)"
    sleep 10
  done
  kill "${pids[@]}" 2>/dev/null; trap - EXIT
  echo "throttle events during test: $(( $(<$tt/package_throttle_count) - t0 ))"
  echo "Waiting 65 s for the logger's last sample..."; sleep 65
  echo "Logged samples during the test (pkg_w is the 1-min average):"
  awk -F, -v s="$(date -d @"$start" -Iseconds)" 'NR > 1 && $1 >= s { print $1, "pkg", $2 "W", $3 "°C" }' "$LOG"
fi

section "History from $LOG"
pctl() { # stdin: numbers -> "median p95 max"
  sort -n | awk '{ v[NR] = $1 } END { if (NR) printf "median %.1f  p95 %.1f  max %.1f", v[int((NR - 1) * .5) + 1], v[int((NR - 1) * .95) + 1], v[NR]; else printf "n/a" }'
}
if [[ -r $LOG ]]; then
  day_ago=$(date -d '24 hours ago' -Iseconds)
  rows() { awk -F, -v since="${1:-}" 'NR > 1 && $1 >= since' "$LOG"; }
  echo "samples: $(rows | wc -l) total ($(sed -n 2p "$LOG" | cut -d, -f1) .. $(tail -1 "$LOG" | cut -d, -f1)), $(rows "$day_ago" | wc -l) in last 24h"
  echo "AC/battery minutes: $(rows | awk -F, '{ if ($11 == "1") a++; else b++ } END { printf "%d / %d", a, b }')"
  echo "pkg power W (all):  $(rows | awk -F, '$2 != "" { print $2 }' | pctl)"
  echo "pkg power W (24h):  $(rows "$day_ago" | awk -F, '$2 != "" { print $2 }' | pctl)"
  echo "pkg temp C (all):   $(rows | awk -F, '$3 != "" { print $3 }' | pctl)"
  echo "pkg temp C (24h):   $(rows "$day_ago" | awk -F, '$3 != "" { print $3 }' | pctl)"
  echo "minutes >= 90C: $(rows | awk -F, '$3 + 0 >= 90' | wc -l), >= 85C: $(rows | awk -F, '$3 + 0 >= 85' | wc -l)"
  echo "minutes at PL1 (sustained load): $(rows | awk -F, '$2 != "" && $2 + 0 >= $5 - 1 { n++; t += $3 } END { printf "%d%s", n, n ? sprintf(", avg temp then %.0fC", t / n) : "" }')"
  echo "throttle events logged: $(rows | awk -F, '{ if (p != "" && $9 + 0 > p + 0) d += $9 - p; p = $9 } END { print d + 0 }') (counter resets each boot)"
  echo "PL1 values seen in log: $(rows | cut -d, -f5,7 | sort | uniq -c | tr '\n' ' ')"
  echo "EPP seen: $(rows | cut -d, -f14 | sort | uniq -c | tr '\n' ' ')"
else
  echo "no history yet ($LOG missing)"
fi
