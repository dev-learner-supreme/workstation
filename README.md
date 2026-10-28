# Workstation (Omarchy 4 / Arch Linux)

Unified system configuration, hardware profiles, dotfiles, and AI agent intelligence for the **Acer Swift Go 14 (SFG14-71)** running **Omarchy 4** (Arch Linux + Hyprland).

Consolidates OS-level tuning, power capping, audio routing, desktop bindings, and the autonomous agent brain into a single version-controlled repository.

---

## ⚡ Quick Restoration Runbook (Fresh Omarchy 4 Install)

Follow these steps chronologically on a clean Omarchy 4 installation:

```
[ Step 1: SSH Auth ] ──► [ Step 2: Clone Repo ] ──► [ Step 3: Run setup.sh ] ──► [ Step 4: Post-Install Checklist ]
```

---

### Step 1: SSH Authentication Setup
Because `workstation` and your work repositories are private, establish SSH authentication before cloning.

#### Path A: Restoring Your Backed-Up Key (Recommended)
1. Place your backed-up `id_ed25519` and `id_ed25519.pub` into `~/.ssh/`.
2. Secure permissions:
   ```bash
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_ed25519
   chmod 644 ~/.ssh/id_ed25519.pub
   ```
3. Enable native systemd SSH agent socket, persist to `~/.bashrc`, and add key:
   ```bash
   systemctl --user enable --now ssh-agent.socket
   echo 'export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"' >> ~/.bashrc
   source ~/.bashrc
   ssh-add ~/.ssh/id_ed25519
   ```
4. Verify GitHub connection:
   ```bash
   ssh -T git@github.com
   # Hi dev-learner-supreme! You've successfully authenticated...
   ```

#### Path B: Generating a Fresh Key (If No Backup)
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "arunraobalappa@gmail.com" -f ~/.ssh/id_ed25519
systemctl --user enable --now ssh-agent.socket
echo 'export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"' >> ~/.bashrc
source ~/.bashrc
ssh-add ~/.ssh/id_ed25519
wl-copy < ~/.ssh/id_ed25519.pub  # Or cat ~/.ssh/id_ed25519.pub
```
*Add the copied public key to **GitHub → Settings → SSH and GPG keys**, then verify with `ssh -T git@github.com`.*

---

### Step 2: Clone Workstation Repository
```bash
git clone git@github.com:dev-learner-supreme/workstation.git ~/workstation
cd ~/workstation
```

---

### Step 3: Run Automated Restoration Script
```bash
./setup.sh
```

#### What `setup.sh` Automates:
* **Package Installation:** Prompts and installs all official packages (`pacman-explicit.txt`), AUR packages (`pacman-foreign.txt`), and Flatpaks (`flatpak.txt` via non-interactive user remote).
* **Root Power Capping:** Deploys `/etc/default/cpu-power-cap` and `/usr/local/sbin/cpu-power-*`, then enables `cpu-power-cap.timer` and `cpu-power-stats.timer`.
* **Hardware Permissions:** Adds user to `uucp` and `dialout` groups for direct ESP32/serial access.
* **Desktop & Dotfiles:** Restores configs from `home/` to `$HOME` with automatic backup of pre-existing files. Configures Foot terminal with `shell=/usr/bin/zsh` and readable font sizing (13pt) on 2.8K OLED.
* **Safe Shell Architecture:** Preserves `/bin/bash` as system login shell for Omarchy OS stability while granting an interactive Zsh experience with `omarchy-zsh`, `fzf`, `zoxide`, `eza`, `starship`, and syntax highlighting.
* **SSH Integration:** Deploys `~/.config/environment.d/ssh-agent.conf`, sets `AddKeysToAgent yes`, and live-exports `SSH_AUTH_SOCK`.
* **Agent Brain & Bridges:** Symlinks `~/.agents -> ~/workstation/agent`, connects Cursor (`~/.cursorrules`), Claude Code (`~/CLAUDE.md`), and Antigravity CLI (`~/.gemini/antigravity-cli/settings.json` with permissions whitelist), installs all skills, and injects Spaces hooks into `~/.claude/settings.json`.
* **Omarchy Shell Plugins & Profiles:** Automatically installs and enables Spaces (`tornikegomareli.spaces`) and Pomodoro (`techywilbur.pomodoro`), disables redundant default workspaces, and sets AC power profile to balanced.

---

### Step 4: Post-Install Verification & Activation

Execute these one-time system settings:

1. **Enable TRIM on LUKS2 (If newly formatted SSD):**
   ```bash
   sudo cryptsetup refresh --allow-discards --persistent root
   ```

2. **Unlock SSH Key into Active Agent:**
   ```bash
   ssh-add ~/.ssh/id_ed25519
   ```

3. **Restart Session:**
   * Log out and log back in (or reboot) to apply hardware group permissions (`uucp`) and Hyprland keybindings.

4. **Verify Health Telemetry:**
   ```bash
   # Agent doctor diagnostic
   ~/.agents/skills/agent-health-check/scripts/doctor.sh

   # Full Omarchy OS hardware & software diagnostic
   ~/.agents/skills/omarchy-health/omarchy-health.sh
   ```

---

## 🏛️ System Architecture & Reference

### Repository Layout
```text
workstation/
├── setup.sh                 # One-shot restoration & system configuration script
├── sync.sh                  # Unified snapshot & push script (with secret scanner)
├── README.md                # System documentation & restoration guide
│
├── system/                  # Root-owned hardware & power capping files (copied to /)
│   ├── etc/default/cpu-power-cap
│   ├── usr/local/sbin/cpu-power-cap
│   ├── usr/local/sbin/cpu-power-stats
│   └── etc/systemd/system/  # cpu-power-cap.service, timers
│
├── home/                    # User dotfiles & desktop configuration (restored to ~)
│   ├── .bashrc
│   ├── .zshrc
│   ├── .ssh/config
│   ├── .config/environment.d/ssh-agent.conf
│   ├── .config/hypr/        # Hyprland bindings, looknfeel, input
│   ├── .config/foot/        # Foot terminal
│   ├── .config/easyeffects/ # Audio auto-gain (JackHack96 preset)
│   └── .config/wireplumber/ # Audio output priority (BT > Headphones > Speaker)
│
├── agent/                   # AI Agent Brain (symlinked directly to ~/.agents/)
│   ├── AGENTS.md            # Global rules (Prod isolation, zero AI attribution, J.A.R.V.I.S.)
│   ├── MEMORY.md            # Dynamic operational memory & active workflows
│   ├── SYSTEM_CAPABILITIES.md
│   ├── hardware/            # Swift Go 14 calibrated profiles (thermals, audio, system)
│   ├── integrations/        # Multi-agent bridges (Claude Code Spaces hooks)
│   ├── projects/            # Project context matrices (CMS, ProjectAgri, Firebase)
│   ├── rules/               # Hierarchical agent rules
│   └── skills/              # Agent skills (thermal-watch, omarchy-health, esp32, etc.)
│
└── state/                   # Machine state manifests
    ├── pacman-explicit.txt  # Explicitly installed pacman packages
    ├── pacman-foreign.txt   # AUR / foreign packages
    ├── flatpak.txt          # Flatpak applications
    ├── omarchy-plugins.txt  # Installed Omarchy desktop plugins
    └── versions.txt         # OS & kernel version stamps
```

---

### Authentication & System Stability Policy (Stock PAM)
To eliminate session freezes, sleep/wake lockups, and rolling update conflicts:
* **Zero PAM Modifications:** `/etc/pam.d/` remains 100% stock Arch Linux / Omarchy defaults.
* **Password-Only Authentication:** Experimental EgisTec fingerprint drivers (`libfprint-egismoc-sdcp`), custom lockscreen QML forks (`arun.lock`), and pacman `IgnorePkg` hooks are strictly excluded.
* **Guaranteed Reliability:** `sudo`, `polkit-1`, and lock screen wake up instantly without USB state machine assertion crashes or hanging authentication daemons.

---

### Power & Thermal Management Profile
Enforced via `/usr/local/sbin/cpu-power-cap` on the Intel Core i5-13500H:
* **PL1 (Sustained):** 18 W
* **PL2 (Burst):** 35 W
* **Tau (Time Window):** 28 seconds
* **Thermal Ceiling:** Package temperatures remain locked strictly below 83°C under sustained load, preserving battery longevity and quiet fan acoustics.

---

### Audio Stack Architecture
* **Realtek ALC256 / Intel SOF:** Handled via PipeWire 1.6+ and WirePlumber 0.5+.
* **Output Priority:** Bluetooth headphones (3000) > Wired 3.5mm headphones (2000) > Laptop speakers (1000) > HDMI/USB (50).
* **Sound Processing:** EasyEffects with the JackHack96 *Advanced Auto Gain* preset autoloaded for laptop speakers; transparent fallback to *Flat* on headphones.

---

## 🔄 Daily Synchronization (Snapshotting)

To capture state changes (installed packages, desktop tweaks, agent memory) and push to GitHub:

```bash
~/workstation/sync.sh         # Local snapshot & commit
~/workstation/sync.sh --push  # Snapshot, commit, and push to origin main
```

> **Security Guard:** `sync.sh` contains an automated regex secret scanner that halts commits if private keys, API tokens, or session credentials are detected in staged files.
