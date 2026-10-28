---
name: system-omarchy
description: "Overview of the user's laptop setup on Omarchy 4.0.6 (Arch + Hyprland) — shell, SSH, disk, desktop look/input, keybindings, bar plugins (as of 2026-10-21)"
metadata:
  node_type: memory
  type: project
  originSessionId: 091ba320-5412-40bc-944a-69eff2850544
  modified: 2026-10-22T03:00:35.612Z
---

Acer Swift Go 14 SFG14-71 (i5-13500H, 15G RAM, eDP-1 at scale 2) runs Omarchy 4.0.6 (Arch, Hyprland 0.56, uwsm, Limine + UKI, LUKS2 → btrfs + snapper) since 2026-10-21. It replaced Ubuntu 26.04 + GNOME; nothing from the Ubuntu setup carried over unless it's listed here or in a linked memory.

**Why:** older memories and backups described Ubuntu-specific setup (apt, apport, GNOME, fnm, /etc tuning files).
**How to apply:** use pacman/yay, `omarchy …` commands and the `omarchy` skill; customize only in `~/.config` (never `/usr/share/omarchy`). Check that a file exists before referring to it. Topic details: [[audio-setup]], [[apps-setup]], [[laptop-thermals]], [[open-items]].

## Shell
- `omarchy-zsh` via `omarchy-setup-zsh`. Login shell stays bash; `~/.bashrc` execs zsh. I re-added the Omarchy env-bootstrap line at the top of `.bashrc`; the original is at `~/.bashrc.backup-20261021-080108`.
- Omarchy defaults come from `/usr/share/omarchy-zsh/shell/`: eza `ls`/`lt`, `cd` → zoxide `zd`, `ff` for fzf.
- User additions go at the bottom of `~/.zshrc`: zsh-autosuggestions, fzf with fd/bat/eza previews, `cdi`=`zi`, an SSH_AUTH_SOCK fallback, ANDROID_HOME. Foot font size is 11 (`~/.config/foot/foot.ini`).

## SSH and disk
- Arch's `ssh-agent.socket` (systemd user) is enabled. SSH_AUTH_SOCK is set in `~/.config/environment.d/ssh_auth_socket.conf`, and `~/.ssh/config` has `AddKeysToAgent yes`.
- The user made a new ed25519 key on 2026-10-21 (`SHA256:l7+4…PYg8`, GitHub user dev-learner-supreme). The old backup key (`SHA256:AGrS…XaeA`) was deleted locally.
- TRIM: the LUKS2 header has the `allow-discards` flag, btrfs mounts with `discard=async` (verified after reboot), and fstrim.timer is left off.

## Desktop (Hyprland Lua overrides in ~/.config/hypr/)
- `input.lua`: `touchpad.natural_scroll = true` (Omarchy default is false).
- `input.lua`: 3-finger horizontal swipe switches workspaces (enabled 2026-10-21 by uncommenting the stock `hl.gesture` line).
- `looknfeel.lua`: `decoration.rounding = 4` (Omarchy default is 0). The shell's `Style.cornerRadius` mirrors this, which is what rounds the bar and Spaces pills.
- `looknfeel.lua`: cursor theme `breeze_cursors` (pkg `breeze-cursors`, official repo) via `hl.env XCURSOR_THEME/HYPRCURSOR_THEME`, size stays Omarchy's 24 (set 2026-10-22). Declined: Bibata (AUR only) and the `hypr-dynamic-cursors` plugin (KDE-style shake-to-enlarge). It's a native plugin that needs a rebuild on every Hyprland update, can force software cursors on Intel and has no versioned releases. Hyprland has no built-in shake-to-find (upstream PR #12677 closed).
- `bindings.lua`, in the "Personal shortcuts" section:

  | Key | Action / note |
  |---|---|
  | SUPER+SHIFT+S | screenshot (Google Maps unbound) |
  | ALT+SPACE | apps menu (SUPER+ALT+SPACE unbound) |
  | F4 / XF86Launch6 | mic mute |
  | F8 / SUPER+L | lock |
  | F9 | airplane mode (`~/.local/bin/airplane-mode-toggle`, rfkill via uaccess) |
  | F10 | touchpad toggle |
  | SUPER+SHIFT+L | workspace layout toggle (moved off SUPER+L) |

- Acer F-row without Fn: F4 sends `XF86Launch6`, and F8 sends SUPER+L (a firmware lock macro). The user doesn't care that apps lose the F-row.
- `omarchy refresh hyprland` / `omarchy reinstall` would reset all of these (with a backup).

## Bar
- Third-party plugin **Spaces** (`tornikegomareli.spaces` 1.4.0, github.com/tornikegomareli/omarchy-spaces). I reviewed it: local-only, no network calls. Built-in `omarchy.workspaces` is disabled.
- Update: `omarchy plugin update tornikegomareli.spaces && omarchy restart shell`.
- On 2026-10-21 the user opened upstream PR #31 (rescan icon dirs when desktop entries change). It fixes new web apps showing a letter instead of their icon until the shell restarts. The fork clone is at `~/Projects/omarchy-spaces`, branch `fix/rescan-icons-on-new-apps`. The installed plugin is kept unmodified. Until it merges, the workaround is `omarchy restart shell`.
- Undo: `omarchy plugin remove tornikegomareli.spaces && omarchy plugin enable omarchy.workspaces`, and remove its hooks.
- Its Claude Code agent-badge hooks are in `~/.claude/settings.json`: UserPromptSubmit/PostToolUse → working, Stop → done, SessionEnd → end. All async. On 2026-10-21 the user had the Notification → waiting hook removed: its pulsing red "!" badge was distracting (it also fires after ~60 s idle). Don't re-add it.

## Workstation repository
- Private GitHub repo **dev-learner-supreme/workstation**, local copy at `~/workstation`.
- `./sync.sh` copies in Claude memory, skills, settings, the customized dotfiles (`home/`), the root power-cap files (`system/`) and package lists (`state/`). It runs a secret scan, then commits. `./sync.sh --push` also pushes.
- Run it after setup changes. If you add a new config file, also add it to the `home_files`/`system_files` lists in `sync.sh`.
- Pushing needs the SSH key in the agent. After a login, the user has to run `ssh-add` (or any ssh command) once in a terminal to unlock it.

## Displays
- Omarchy handles monitors itself. `~/.config/hypr/monitors.lua` has a catch-all rule (preferred mode, auto position, auto scale, GDK_SCALE 2), `omarchy-hyprland-monitor-watch` watches hotplug, and the lid-switch bindings call `omarchy-hyprland-monitor-clamshell`.
- On 2026-10-21 the user **declined the hyprmoncfg plugin** (`crmne.hyprmoncfg`). It takes over display management: its daemon stops Omarchy's monitor watcher, adds an include line to the end of hyprland.lua, and writes a marked block into monitors.lua.
- For a fixed external-monitor layout, add an `hl.monitor({...})` rule for that output in `monitors.lua`. Don't suggest third-party display managers.
- On 2026-10-21 the user **declined Mirador** (`sanjyay/Mirador`, workspace overview overlay). The code is clean, but its suggested bindings take SUPER+TAB/ALT+TAB/SUPER+W/arrows/numbers and plain SHIFT+TAB, and the user doesn't need an overview.
- On 2026-10-21 the user also **declined Omapop** (`io.github.jondkinney.omapop`, select-text popup; additive, low risk) **and Hymission** (`io.github.gfhdhytghd.hymission`). Hymission is a native Hyprland C++ plugin that must be rebuilt on every Hyprland update; it replaces SUPER+TAB/SUPER+SHIFT+TAB and edits omarchy-menu.jsonc. The user's bar for plugins: no conflicts with Omarchy and safe across updates. Review a plugin's source before recommending it.

## Health checks
- Skill **omarchy-health** (`~/.claude/skills/omarchy-health/omarchy-health.sh [--offline] [--no-thermal]`, ~5 s, read-only) checks system health and drift for every customization in these memories, then runs the thermal-watch quick report.
- Its known-harmless baseline (TPM units, ~30 journal errors per boot) is in its SKILL.md.
- When a new customization is added, add a check for it to the script too.
- First run on 2026-10-21: 56 OK. The only warnings were the Arduino AppImage not installed yet and the repo not yet pushed.
