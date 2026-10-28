#!/bin/bash
# Omarchy health check for this laptop: system health plus drift detection for
# every customization recorded in Claude's memory. Read-only, no root.
# Usage: omarchy-health.sh [--offline] [--no-thermal]
#   --offline     skip checks that use the network (updates, DNS, GitHub)
#   --no-thermal  skip the thermal-watch quick report at the end
set -u
offline=0 thermal=1
for a in "$@"; do
  case $a in
    --offline) offline=1 ;;
    --no-thermal) thermal=0 ;;
  esac
done

ok=0 warn=0 fail=0
OK() { printf '  OK    %s\n' "$*"; ok=$((ok + 1)); }
WARN() { printf '  WARN  %s\n' "$*"; warn=$((warn + 1)); }
FAIL() { printf '  FAIL  %s\n' "$*"; fail=$((fail + 1)); }
section() { printf '\n== %s ==\n' "$1"; }
has() { command -v "$1" >/dev/null 2>&1; }
# check "description" command... : OK if the command succeeds, else WARN
check() { local d=$1; shift; if "$@" >/dev/null 2>&1; then OK "$d"; else WARN "$d"; fi; }

# Known harmless failures on this machine (see the SKILL.md baseline).
BENIGN_UNITS='systemd-pcrlogin@|systemd-pcrproduct|systemd-tpm2-setup-early'

printf 'omarchy-health %s | %s | kernel %s | up %s\n' "$(date -Iseconds)" \
  "$(omarchy version 2>/dev/null)" "$(uname -r)" "$(uptime -p | sed 's/^up //')"

section "Updates"
if ((offline)); then
  echo "  (skipped: --offline)"
else
  if out=$(timeout 30 omarchy-update-available 2>&1); then WARN "Omarchy update available: $out"; else OK "$out"; fi
  n=$(timeout 30 checkupdates 2>/dev/null | wc -l)
  ((n == 0)) && OK "no pending repo updates" || WARN "$n repo packages have updates (omarchy update)"
  n=$(timeout 30 yay -Qua 2>/dev/null | wc -l)
  ((n == 0)) && OK "no pending AUR updates" || WARN "$n AUR packages have updates"
fi
[[ -d "/usr/lib/modules/$(uname -r)" ]] && OK "running kernel modules present" || WARN "kernel updated on disk (reboot required for new modules)"
if [[ -f /tmp/omarchy-update.log ]]; then
  echo "  last update log analysis: $(omarchy update analyze logs 2>&1 | tail -3)"
else
  echo "  no update log this boot (omarchy update writes /tmp/omarchy-update.log)"
fi

section "Services"
failed=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
real=$(grep -vE "$BENIGN_UNITS" <<<"$failed" | grep -v '^$' || true)
benign=$(grep -cE "$BENIGN_UNITS" <<<"$failed" || true)
[[ -z $real ]] && OK "no failed system units (${benign} known-benign TPM units ignored)" || FAIL "failed system units: $(tr '\n' ' ' <<<"$real")"
ufailed=$(systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
[[ -z ${ufailed// /} ]] && OK "no failed user units" || FAIL "failed user units: $ufailed"
for u in pipewire wireplumber pipewire-pulse; do
  check "user service $u active" systemctl --user is-active --quiet "$u"
done
for u in NetworkManager systemd-resolved thermald power-profiles-daemon bluetooth ufw cpu-power-cap.timer cpu-power-stats.timer; do
  check "system unit $u active" systemctl is-active --quiet "$u"
done

section "Logs (this boot)"
errs=$(journalctl -b -p 3 --no-pager -q 2>/dev/null | wc -l)
echo "  $errs error-level journal lines; top sources:"
journalctl -b -p 3 --no-pager -q -o json 2>/dev/null |
  jq -r '.SYSLOG_IDENTIFIER // ._COMM // "?"' 2>/dev/null | sort | uniq -c | sort -rn | head -6 | sed 's/^/    /'
cores=$(coredumpctl list --since "$(uptime -s)" --no-pager --no-legend 2>/dev/null | grep -vc '^$')
((cores == 0)) && OK "no crashes (core dumps) this boot" || WARN "$cores core dumps this boot (coredumpctl list; diagnose-crash skill)"
ooms=$(journalctl -b -k --no-pager -q 2>/dev/null | grep -ciE 'out of memory|oom-kill')
((ooms == 0)) && OK "no OOM kills this boot" || WARN "$ooms OOM-kill messages this boot"
taint=$(cat /proc/sys/kernel/tainted 2>/dev/null || echo 0)
((taint == 0)) && OK "kernel clean (not tainted)" || WARN "kernel tainted: $taint (/proc/sys/kernel/tainted)"
edac_errs=0
for f in /sys/devices/system/edac/mc/mc*/[cu]e_count; do [[ -r $f ]] && edac_errs=$((edac_errs + $(<"$f"))); done
((edac_errs == 0)) && OK "no hardware memory (EDAC) errors" || WARN "$edac_errs hardware memory (EDAC) errors reported"

section "Disk and memory"
df -h --output=target,size,used,avail,pcent / /boot 2>/dev/null | sed 's/^/  /'
use=$(df --output=pcent / | tail -1 | tr -dc 0-9)
((use < 85)) && OK "root filesystem ${use}% used" || WARN "root filesystem ${use}% used"
dmax=$(cat /sys/block/dm-0/queue/discard_max_bytes 2>/dev/null || echo 0)
((dmax > 0)) && findmnt -no OPTIONS / | grep -q 'discard=async' && OK "TRIM active (LUKS allow-discards + btrfs discard=async)" || FAIL "TRIM not active (discard_max_bytes=$dmax)"
if has btrfs; then
  btrfs_errs=0
  while read -r _ c; do btrfs_errs=$((btrfs_errs + c)); done < <(btrfs device stats / 2>/dev/null | awk '{print $1, $2}')
  ((btrfs_errs == 0)) && OK "btrfs device stats clean (0 hardware I/O or corruption errors)" || FAIL "btrfs reports $btrfs_errs device I/O or corruption errors"
fi
check "snapper-cleanup.timer active" systemctl is-active --quiet snapper-cleanup.timer
read -r _ mt _ mu _ <<<"$(free -m | awk '/^Mem/ {print "t", $2, "u", $7}')"
echo "  memory: ${mu} MiB available of ${mt} MiB; swap: $(swapon --noheadings --show=NAME,SIZE,USED 2>/dev/null | tr '\n' ';')"
if has zramctl; then
  zinfo=$(zramctl --noheadings --output DATA,COMPR /dev/zram0 2>/dev/null)
  [[ -n $zinfo ]] && echo "  zram compression: $(awk '{printf "%s data -> %s compressed", $1, $2}' <<<"$zinfo")"
fi
swapon --show=NAME --noheadings 2>/dev/null | grep -q zram && OK "zram swap active" || WARN "no zram swap"
jsize=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[MG]B?' | head -1)
[[ -n $jsize ]] && echo "  journal storage: $jsize"
nvt=$(sensors 2>/dev/null | awk '/^nvme/ {f = 1} f && /Composite/ {print $2; exit}')
[[ -n $nvt ]] && echo "  NVMe temperature: $nvt"

section "Packages"
orph=$(pacman -Qdtq 2>/dev/null | wc -l)
((orph == 0)) && OK "no orphaned packages" || WARN "$orph orphaned packages (pacman -Qdtq)"
pacnew=$(find /etc -name '*.pacnew' -o -name '*.pacsave' 2>/dev/null | wc -l)
((pacnew == 0)) && OK "no .pacnew/.pacsave files" || WARN "$pacnew .pacnew/.pacsave files in /etc need merging"
[[ -e /var/lib/pacman/db.lck ]] && ! pgrep -x pacman >/dev/null && FAIL "stale pacman lock /var/lib/pacman/db.lck" || OK "no stale pacman lock"
echo "  AUR/foreign packages: $(pacman -Qqm 2>/dev/null | tr '\n' ' ')"

section "Desktop"
cerr=$(hyprctl configerrors 2>/dev/null | grep -v '^$')
[[ -z $cerr ]] && OK "Hyprland config has no errors" || FAIL "Hyprland config errors: $cerr"
pgrep -f 'omarchy-shell|quickshell' >/dev/null && OK "Omarchy shell running" || FAIL "Omarchy shell not running (omarchy restart shell)"
if has hyprctl; then
  m_info=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.name=="eDP-1") | "\(.width)x\(.height)@\(.refreshRate|round)Hz scale \(.scale)"' 2>/dev/null)
  if [[ -n $m_info ]]; then
    [[ $m_info == "2880x1800@90Hz scale 2" ]] && OK "internal display eDP-1: $m_info" || WARN "internal display eDP-1 mode: $m_info (expected 2880x1800@90Hz scale 2)"
  fi
fi
[[ $(hyprctl getoption input:touchpad:natural_scroll -j 2>/dev/null | jq -r '.bool // (.int == 1)') == true ]] && OK "natural scrolling on" || WARN "natural scrolling off (input.lua override missing?)"
grep -q '^hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })' ~/.config/hypr/input.lua && OK "3-finger workspace swipe on" || WARN "3-finger workspace swipe missing (input.lua)"
r=$(hyprctl getoption decoration:rounding -j 2>/dev/null | jq -r .int)
[[ $r == 4 ]] && OK "rounding = 4" || WARN "rounding = $r (expected 4, looknfeel.lua)"
ct=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")
[[ $ct == breeze_cursors && -d /usr/share/icons/breeze_cursors ]] && OK "cursor theme = breeze_cursors" || WARN "cursor theme = ${ct:-unset} (expected breeze_cursors, looknfeel.lua + breeze-cursors pkg)"
binds=$(omarchy menu keybindings --print 2>/dev/null)
for b in 'SUPER SHIFT \+ S +→ Screenshot' 'ALT \+ SPACE +→ Apps menu' 'F4 +→ Mute microphone' 'XF86Launch6 +→ Mute microphone' \
  'F8 +→ Lock system' 'SUPER \+ L +→ Lock system' 'F9 +→ Toggle airplane mode' 'F10 +→ Toggle touchpad' 'SUPER SHIFT \+ L +→ Toggle workspace layout'; do
  grep -qE "^$b" <<<"$binds" || WARN "keybinding missing: ${b//\\/}"
done
grep -qE '^SUPER ALT \+ SPACE' <<<"$binds" && WARN "SUPER+ALT+SPACE is bound again (should be unbound)" || OK "custom keybindings present"
check "airplane-mode-toggle script installed" test -x "$HOME/.local/bin/airplane-mode-toggle"
plugins=$(omarchy plugin list 2>/dev/null)
grep -qE '^tornikegomareli.spaces +enabled' <<<"$plugins" && grep -qE '^omarchy.workspaces +disabled' <<<"$plugins" &&
  OK "Spaces enabled, built-in workspaces disabled" || WARN "bar plugins changed: $(grep -E 'spaces|workspaces' <<<"$plugins" | tr -s ' ' | tr '\n' ';')"
jq -e '.hooks.Stop[0].hooks[0].command | test("spaces")' "$HOME/.claude/settings.json" >/dev/null 2>&1 &&
  OK "Spaces Claude Code hooks present" || WARN "Spaces Claude Code hooks missing from ~/.claude/settings.json"
jq -e '[.hooks.Notification[]?.hooks[]?.command | select(test("spaces"))] | length == 0' "$HOME/.claude/settings.json" >/dev/null 2>&1 &&
  OK "Spaces \"needs input\" badge hook stays removed" || WARN "Spaces Notification hook is back (user removed it 2026-10-21: red ! badge was distracting)"
# The installed Spaces copy must stay a clean checkout so `omarchy plugin update` can pull.
# Fixes go through the fork in ~/Projects/omarchy-spaces (upstream PR #31).
sp="$HOME/.config/omarchy/plugins/tornikegomareli.spaces"
if [[ -L $sp ]]; then WARN "Spaces is a symlink ($(readlink "$sp")), not the installed plugin; restore it"
elif [[ -n $(git -C "$sp" status --porcelain 2>/dev/null) ]]; then WARN "Spaces install has local edits (git -C $sp status); updates will fail"
else OK "Spaces install is an unmodified checkout"; fi
grep -qE '^\s*omarchy_preinstalled_bindings\s*=\s*false' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null &&
  OK "preinstalled keybindings disabled" || WARN "preinstalled keybindings enabled (hyprland.lua)"

section "Audio"
pgrep -x easyeffects >/dev/null && OK "EasyEffects running" || FAIL "EasyEffects not running"
grep -q -- '--hide-window' "$HOME/.config/autostart/easyeffects-service.desktop" 2>/dev/null && OK "EasyEffects autostart (hidden)" || WARN "EasyEffects autostart entry missing or not hidden"
sink=$(pactl get-default-sink 2>/dev/null)
echo "  default output: $sink"
pre=$(easyeffects -a output 2>/dev/null | head -1)
case $sink in
  *Speaker__sink) [[ $pre == "Advanced Auto Gain" ]] && OK "speakers use Advanced Auto Gain" || WARN "speakers use preset '$pre' (expected Advanced Auto Gain)" ;;
  *) [[ $pre == Flat ]] && OK "non-speaker output uses Flat" || WARN "output uses preset '$pre' (expected Flat)" ;;
esac
check "WirePlumber output-priority config present" test -f "$HOME/.config/wireplumber/wireplumber.conf.d/60-output-priority.conf"
check "WirePlumber priority-reset script present" test -f "$HOME/.local/share/wireplumber/scripts/output-priority-reset.lua"
journalctl --user -b -u wireplumber --no-pager -q 2>/dev/null | grep -iE 'output-priority' | grep -iqE 'error|fail' &&
  FAIL "WirePlumber reports errors in output-priority-reset.lua" || OK "WirePlumber custom script loads cleanly"
systemctl --user is-active --quiet omarchy-speaker-tuning.service && WARN "Omarchy speaker tuning is on (conflicts with EasyEffects)" || OK "Omarchy speaker tuning off (no EasyEffects conflict)"

section "Shell, SSH and apps"
grep -q 'exec zsh' "$HOME/.bashrc" 2>/dev/null && grep -q 'env-bootstrap' "$HOME/.bashrc" && OK "bash hands off to zsh, env-bootstrap kept" || WARN ".bashrc changed (zsh hand-off or env-bootstrap missing)"
grep -q 'zsh-autosuggestions' "$HOME/.zshrc" 2>/dev/null && OK "zsh additions present" || WARN "zsh additions missing from ~/.zshrc"
systemctl --user is-active --quiet ssh-agent.socket && [[ $(systemctl --user show-environment | grep -c '^SSH_AUTH_SOCK=') -gt 0 ]] &&
  OK "ssh-agent socket active, SSH_AUTH_SOCK in session" || WARN "ssh-agent socket or SSH_AUTH_SOCK missing"
check "SSH key present" test -f "$HOME/.ssh/id_ed25519"
id -nG | grep -qw uucp && OK "user in uucp (Arduino serial)" || WARN "user not in uucp (serial ports need root)"
check "Android Studio installed" test -x "$HOME/.local/share/android-studio/bin/studio"
[[ -d $HOME/Android/Sdk ]] && OK "Android SDK present" || WARN "Android SDK not installed yet (first-run wizard)"
flatpak list --app --columns=application 2>/dev/null | grep -q it.mijorus.gearlever && OK "Gear Lever installed" || WARN "Gear Lever missing"
ls "$HOME/AppImages"/*rduino* >/dev/null 2>&1 && OK "Arduino IDE AppImage present" || WARN "Arduino IDE AppImage not installed yet"
[[ $(cat "$HOME/.local/state/omarchy/powerprofiles/ac" 2>/dev/null) == balanced ]] && OK "AC power profile saved as balanced" || WARN "AC power profile not saved as balanced"

section "Network and security"
nmcli -t -f STATE general 2>/dev/null | grep -q '^connected' && OK "NetworkManager connected" || WARN "NetworkManager: $(nmcli -t -f STATE general 2>/dev/null)"
timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes && OK "clock NTP-synchronized" || WARN "clock not NTP-synchronized"
if ((!offline)); then
  check "DNS resolves archlinux.org" resolvectl query --legend=no archlinux.org
  timeout 10 ssh -o BatchMode=yes -T git@github.com 2>&1 | grep -q 'successfully authenticated' &&
    OK "GitHub SSH works" || WARN "GitHub SSH not authenticated (key not in agent? run ssh-add)"
fi
if has iw; then
  wdev=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2}' | head -1)
  if [[ -n $wdev ]]; then
    wlink=$(iw dev "$wdev" link 2>/dev/null)
    if grep -q 'Connected to' <<<"$wlink"; then
      w_ssid=$(awk -F': ' '/SSID/{print $2}' <<<"$wlink")
      w_sig=$(awk -F': ' '/signal/{print $2}' <<<"$wlink")
      OK "Wi-Fi connected to '$w_ssid' ($w_sig)"
    fi
  fi
fi
if has tailscale; then
  ts_ip=$(tailscale status 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 | awk '{print $1}')
  if [[ -n $ts_ip ]]; then
    if tailscale status 2>&1 | grep -iq 'version mismatch'; then
      WARN "Tailscale active ($ts_ip), but daemon version mismatch (restart tailscaled)"
    else
      OK "Tailscale active ($ts_ip)"
    fi
  elif systemctl is-active --quiet tailscaled; then
    WARN "Tailscale daemon active but not connected"
  fi
fi
rfkill -n -o SOFT 2>/dev/null | grep -q '^blocked' && WARN "a radio is soft-blocked (airplane mode on?)" || OK "radios unblocked"
check "ufw firewall active" systemctl is-active --quiet ufw
has fwupdmgr && echo "  fwupd installed: run 'fwupdmgr get-updates' to check firmware" || echo "  fwupd not installed (optional: omarchy update firmware)"

section "Battery"
for p in /sys/class/power_supply/BAT*; do
  kind=energy; [[ -r $p/energy_full ]] || kind=charge
  [[ -r $p/${kind}_full ]] || continue
  h=$(awk -v f="$(<"$p/${kind}_full")" -v d="$(<"$p/${kind}_full_design")" 'BEGIN { printf "%.1f", f * 100 / d }')
  echo "  ${p##*/}: $(<"$p/status") $(<"$p/capacity")%, health ${h}%, cycles $(cat "$p/cycle_count" 2>/dev/null)"
  awk -v h="$h" 'BEGIN { exit !(h >= 80) }' && OK "battery health ${h}%" || WARN "battery health ${h}% (below 80%)"
done

section "Setup history repo (~/omarchy-setup)"
R=$HOME/omarchy-setup
if [[ -d $R/.git ]]; then
  last=$(git -C "$R" log -1 --format='%cr (%s)')
  echo "  last snapshot: $last"
  # Compare live files with the last snapshot without writing anything.
  drift=0
  while read -r f; do
    [[ -e $HOME/$f ]] && ! cmp -s "$HOME/$f" "$R/home/$f" && { echo "    changed since snapshot: ~/$f"; drift=1; }
  done < <(cd "$R/home" && find . -type f | sed 's|^\./||')
  ! diff -rq "$HOME/.claude/projects/-home-arun/memory" "$R/claude/memory" >/dev/null 2>&1 && { echo "    changed since snapshot: Claude memory"; drift=1; }
  ((drift)) && WARN "files changed since the last snapshot (run ~/omarchy-setup/sync.sh)" || OK "snapshot up to date"
  if ! git -C "$R" rev-parse -q --verify '@{upstream}' >/dev/null 2>&1; then
    WARN "repo never pushed (run: ~/omarchy-setup/sync.sh --push)"
  else
    ahead=$(git -C "$R" rev-list --count '@{upstream}..HEAD')
    ((ahead == 0)) && OK "all snapshots pushed" || WARN "$ahead snapshot commits not pushed (ssh-add; sync.sh --push)"
  fi
else
  FAIL "~/omarchy-setup repo missing"
fi

if ((thermal)) && [[ -x $HOME/.claude/skills/thermal-watch/thermal-watch.sh ]]; then
  section "Thermals and power cap (thermal-watch quick report)"
  "$HOME/.claude/skills/thermal-watch/thermal-watch.sh" | sed 's/^/  /'
fi

printf '\n== Summary: %d OK, %d WARN, %d FAIL ==\n' "$ok" "$warn" "$fail"
