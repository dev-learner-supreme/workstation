---
name: omarchy-health
description: Full health check of the user's Omarchy laptop — updates, failed services, logs/crashes, disk/TRIM, packages, Hyprland config, audio, shell/SSH/apps, network, battery, setup-repo drift — plus a check that every customization we made is still in effect, and the thermal/power-cap report. Use when the user runs /omarchy-health or asks whether the system/Omarchy install is healthy or anything has drifted after an update.
---

# Omarchy health check

A read-only check of the whole laptop (Acer Swift Go 14 SFG14-71, Omarchy).
It does two jobs:
1. **System health**: updates, services, crashes, disk, packages, network, battery.
2. **Drift detection**: every customization recorded in memory
   ([[system-omarchy]], [[audio-setup]], [[apps-setup]], [[laptop-thermals]])
   is checked to see whether it still exists and still works. Omarchy updates
   and `omarchy refresh …` can silently undo them.

For power and cooling, it includes the `thermal-watch` quick report. Use the
`thermal-watch` skill itself for the deep dive (history trends, `--load` stress test).

## 1. Run

```bash
~/.claude/skills/omarchy-health/omarchy-health.sh             # full (~5-10 s, uses network)
~/.claude/skills/omarchy-health/omarchy-health.sh --offline   # skip updates/DNS/GitHub checks
~/.claude/skills/omarchy-health/omarchy-health.sh --no-thermal
```

The script prints `OK` / `WARN` / `FAIL` lines per section and a summary count.
Use a Bash timeout of at least 180000 ms. If a check looks wrong, inspect the
script before blaming the system: a false alarm is a bug to fix in
`omarchy-health.sh`.

Also read `open-items.md` in memory, and mark items done when the report shows
them done. For example, "Android SDK present" closes the first-run-wizard item.

## 2. Known-harmless baseline (don't report these as problems)

- **Failed units** `systemd-pcrlogin@1000`, `systemd-pcrproduct`, `systemd-tpm2-setup-early`
  ("Failed to initialize NvPCR index"): systemd 262 TPM measurement units with no
  TPM NV index. They are cosmetic. The script already ignores them.
  The optional fix is `sudo systemctl mask systemd-pcrproduct.service systemd-tpm2-setup-early.service systemd-pcrlogin@.service`.
- **Error-level journal lines (~30 per boot)**. The normal sources are:
  - kernel: X.509 cert -65, i801 SMBus busy, Acer WMBF firmware bug, BT firmware retry
  - systemd-pcrextend / systemd-tpm2-setup: TPM, as above
  - wpa_supplicant: multicast RX
  - sddm-helper: autologin keyring unlock
  - pipewire / wireplumber: RTKit ServiceUnknown, since rtkit isn't installed
  New sources, or a sudden jump in count, are worth a look.
- **Swap**: zram (prio 100) plus a 15 G swapfile, which is for hibernation. Both are expected.
- **Secure Boot off**: this is normal for Omarchy with Limine.
- **fwupd not installed**: optional.

## 3. Interpreting the rest

| Section | If WARN/FAIL | Likely cause and fix |
|---|---|---|
| Updates | updates available | Suggest `omarchy update`. Afterwards, re-run this skill to catch drift |
| Updates | kernel modules missing | Kernel was upgraded on disk; reboot required to load new modules |
| Services | real failed unit | `systemctl status <unit>`, `journalctl -b -u <unit>` |
| Logs | core dumps | Use the `diagnose-crash` skill |
| Logs | kernel tainted | Non-zero `/proc/sys/kernel/tainted`: check `dmesg` for MCEs or forced modules |
| Logs | EDAC errors | Hardware RAM controller reported errors; check RAM stability |
| Disk | TRIM not active | Check `cryptsetup luksDump` flags and `findmnt /`. It was set up 2026-10-21 |
| Disk | btrfs device errors | `btrfs device stats /`: I/O or checksum corruption detected on NVMe |
| Packages | `.pacnew` files | Diff them with the live file and merge. Never overwrite blindly |
| Desktop | display mode changed | Primary eDP-1 not 2880x1800@90Hz scale 2; check `~/.config/hypr/monitors.lua` |
| Desktop | natural scroll / rounding / keybindings missing | A `~/.config/hypr/*.lua` override was reset (`omarchy refresh hyprland`?). Restore it from `~/omarchy-setup/home/.config/hypr/` |
| Desktop | Spaces disabled or workspaces enabled | An `omarchy plugin` change or a `refresh shell` |
| Desktop | Spaces install has local edits / is a symlink | Left over from testing a fix. `git -C ~/.config/omarchy/plugins/tornikegomareli.spaces checkout -- .` (or remove the link and `omarchy plugin add` it again), then `omarchy restart shell`. Fork work lives in `~/Projects/omarchy-spaces` |
| Desktop | preinstalled keybindings enabled | `~/.config/hypr/hyprland.lua` was reset (`omarchy refresh hyprland`?); restore `omarchy_preinstalled_bindings = false` |
| Audio | EasyEffects not running / wrong preset | Restart it with `systemctl --user start 'app-easyeffects\x2dservice@autostart.service'`, then check the autoload files |
| Audio | Omarchy speaker tuning on | It conflicts with EasyEffects: `omarchy audio tuning off` |
| Shell/SSH | `.bashrc` changed | Re-running `omarchy-setup-zsh` drops the env-bootstrap line. Restore it from the repo copy |
| Network | GitHub SSH fails | The key isn't in the agent yet this login: the user runs `ssh-add` |
| Network | Tailscale version mismatch | Pacman updated tailscale; run `sudo systemctl restart tailscaled` |
| Setup repo | changed since snapshot / not pushed | Offer `~/omarchy-setup/sync.sh` (and `--push`) |
| Thermals | see the thermal-watch skill's table | |

## 4. Report back

- Lead with the summary count and a one-line verdict: healthy, minor issues, or needs attention.
- Then list each WARN/FAIL that is **not** in the baseline, with its cause and
  the exact fix command. Say which fixes need root.
- Then list any open items that are now done (and update `open-items.md`).
- Don't apply fixes without asking. For drift, offer to restore from `~/omarchy-setup`.
- If the thermal section shows something, follow the `thermal-watch` skill's rules,
  and append its dated line to `laptop-thermals.md`.
