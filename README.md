# workstation

Unified system configuration, hardware profiles, dotfiles, and AI agent intelligence for the **Acer Swift Go 14 (SFG14-71)** running **Omarchy 4** (Arch Linux + Hyprland).

Consolidates OS-level tuning, power capping, audio routing, desktop bindings, and the autonomous agent brain into a single version-controlled repository.

---

## Repository Layout

```
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

## Quick Restoration (Fresh Omarchy 4 Install)

### 1. Clone Repository
```bash
git clone git@github.com:dev-learner-supreme/workstation.git ~/workstation
cd ~/workstation
```

### 2. Run Restoration & Configuration Script
```bash
./setup.sh
```

`setup.sh` guides package installations manually via Omarchy/Pacman, and automatically executes:
* Deploys `/etc/default/cpu-power-cap` and `/usr/local/sbin/cpu-power-cap`
* Enables root systemd timers (`cpu-power-cap.timer`, `cpu-power-stats.timer`)
* Grants ESP32 and serial hardware access (`usermod -aG uucp,dialout $USER`)
* Restores desktop dotfiles to `$HOME` (creating timestamped backups of existing files)
* Symlinks `~/.agents` to `workstation/agent` and bridges Cursor (`~/.cursorrules`) and Claude Code (`~/CLAUDE.md`)

---

## Package Management Policy

Per workstation policy, packages are reviewed and installed via Omarchy or Pacman:

```bash
# Review & install explicit pacman packages
sudo pacman -S --needed - < state/pacman-explicit.txt

# Install AUR / foreign packages via yay
yay -S --needed - < state/pacman-foreign.txt

# Or install individual tools via Omarchy
omarchy package install <package-name>
```

---

## Post-Install Manual Steps

Run once after initial restoration:

1. **TRIM on LUKS2:**
   ```bash
   sudo cryptsetup refresh --allow-discards --persistent root
   ```

2. **Spaces Bar Plugin:**
   ```bash
   omarchy plugin add https://github.com/tornikegomareli/omarchy-spaces.git --enable
   omarchy plugin disable omarchy.workspaces
   ```

3. **Balanced AC Power Profile:**
   ```bash
   omarchy-powerprofiles-set ac balanced
   ```

4. **SSH Agent Socket:**
   ```bash
   systemctl --user enable --now ssh-agent.socket
   ssh-add
   ```

---

## Snapshot & Synchronization

To capture state changes (installed packages, desktop tweaks, agent memory) and push to GitHub:

```bash
~/workstation/sync.sh         # Local snapshot & commit
~/workstation/sync.sh --push  # Snapshot, commit, and push to origin main
```

> **Security Guard:** `sync.sh` contains an automated secret scanner that blocks commits if SSH private keys, Google API keys, or AI auth tokens are detected in the repository.
