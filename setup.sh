#!/usr/bin/env bash
# ==============================================================================
# Workstation Restoration & Configuration Script
# Target: Acer Swift Go 14 (SFG14-71) running Omarchy 4 (Arch + Hyprland)
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_TS="$(date '+%Y%m%d-%H%M%S')"
BACKUP_DIR="$HOME/.workstation-backup-$BACKUP_TS"

# Styling
BOLD="$(tput bold 2>/dev/null || echo '')"
GREEN="$(tput setaf 2 2>/dev/null || echo '')"
YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
BLUE="$(tput setaf 4 2>/dev/null || echo '')"
RED="$(tput setaf 1 2>/dev/null || echo '')"
RESET="$(tput sgr0 2>/dev/null || echo '')"

# Command line arguments
AUTO_INSTALL=false
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --auto|-y) AUTO_INSTALL=true ;;
    --dry-run|-n) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --auto, -y     Non-interactive mode (auto-approve all prompts)"
      echo "  --dry-run, -n  Preview all changes without modifying system or home files"
      echo "  --help, -h     Show this help message"
      exit 0
      ;;
  esac
done

echo "${BOLD}${BLUE}=== Workstation Restoration & Configuration ===${RESET}"
echo "Repository: $REPO_DIR"
echo "Timestamp:  $(date)"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "${BOLD}${YELLOW}Mode:       DRY RUN (Simulation only — zero file/system mutations)${RESET}"
else
  echo "Mode:       Live Execution"
fi
echo ""

# Prevent running directly as root
if [[ "$EUID" -eq 0 ]]; then
  echo "${RED}[!] Please run setup.sh as your standard user, not as root.${RESET}"
  echo "    The script will invoke sudo when root privileges are required."
  exit 1
fi

if [[ "$DRY_RUN" != "true" ]]; then
  # Request sudo upfront
  sudo -v || { echo "${RED}[!] Sudo authentication failed.${RESET}"; exit 1; }

  # Keep sudo alive in background
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  SUDO_PID=$!
  trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT
fi

# ==============================================================================
# 1. Package Installation (Pacman & Flatpak)
# ==============================================================================
echo "${BOLD}${YELLOW}--- [1/6] Package Installation ---${RESET}"
PACMAN_STATE="$REPO_DIR/state/pacman-explicit.txt"
FOREIGN_STATE="$REPO_DIR/state/pacman-foreign.txt"
FLATPAK_STATE="$REPO_DIR/state/flatpak.txt"

# Official Arch / Omarchy packages
if [[ -f "$PACMAN_STATE" && -s "$PACMAN_STATE" ]]; then
  pkg_count="$(wc -l < "$PACMAN_STATE")"
  echo "Recorded explicit pacman packages: ${BOLD}$pkg_count${RESET}"

  DO_PACMAN="Y"
  if [[ "$AUTO_INSTALL" != "true" && "$DRY_RUN" != "true" ]]; then
    read -r -p "${BOLD}Upgrade system & install recorded pacman packages? [Y/n]: ${RESET}" DO_PACMAN
    DO_PACMAN="${DO_PACMAN:-Y}"
  fi

  if [[ "$DO_PACMAN" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "    [DRY-RUN] Would run: sudo pacman -Syu --needed --noconfirm - < $PACMAN_STATE"
    else
      echo "[+] Synchronizing databases, upgrading system, and installing packages..."
      # Use -Syu to strictly prevent partial upgrades on Arch Linux
      sudo pacman -Syu --needed --noconfirm - < "$PACMAN_STATE"
      echo "${GREEN}[✓] Pacman packages synchronized and installed successfully.${RESET}"
    fi
  else
    echo "${YELLOW}[!] Skipping pacman package installation.${RESET}"
  fi
fi

# Foreign / AUR packages
if [[ -f "$FOREIGN_STATE" && -s "$FOREIGN_STATE" ]]; then
  aur_count="$(wc -l < "$FOREIGN_STATE")"
  echo "Recorded foreign/AUR packages: ${BOLD}$aur_count${RESET}"
  if command -v yay &>/dev/null; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "    [DRY-RUN] Would run: yay -Syu --needed --noconfirm - < $FOREIGN_STATE"
    else
      echo "[+] Upgrading and installing AUR packages via yay..."
      yay -Syu --needed --noconfirm - < "$FOREIGN_STATE"
      echo "${GREEN}[✓] AUR packages installed successfully.${RESET}"
    fi
  else
    echo "${YELLOW}[!] 'yay' not found; install AUR packages manually if needed:${RESET}"
    echo "    yay -Syu --needed - < \"$FOREIGN_STATE\""
  fi
fi

# Flatpak applications
if [[ -f "$FLATPAK_STATE" && -s "$FLATPAK_STATE" ]] && command -v flatpak &>/dev/null; then
  flatpak_count="$(wc -l < "$FLATPAK_STATE")"
  echo "Recorded Flatpak applications: ${BOLD}$flatpak_count${RESET}"
  
  DO_FLATPAK="Y"
  if [[ "$AUTO_INSTALL" != "true" && "$DRY_RUN" != "true" ]]; then
    read -r -p "${BOLD}Install recorded Flatpak applications? [Y/n]: ${RESET}" DO_FLATPAK
    DO_FLATPAK="${DO_FLATPAK:-Y}"
  fi

  if [[ "$DO_FLATPAK" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "    [DRY-RUN] Would configure flathub user remote and install:"
      while IFS=$'\t' read -r app origin; do
        [[ -z "$app" ]] && continue
        echo "      - $app (from ${origin:-flathub})"
      done < "$FLATPAK_STATE"
    else
      echo "[+] Ensuring flathub user remote is configured..."
      flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
      while IFS=$'\t' read -r app origin; do
        [[ -z "$app" ]] && continue
        echo "[+] Checking flatpak: $app..."
        if flatpak info "$app" &>/dev/null; then
          echo "    [✓] $app is already installed."
        else
          echo "    -> Installing $app from ${origin:-flathub}..."
          flatpak --user install -y --noninteractive "${origin:-flathub}" "$app" 2>/dev/null || \
          sudo flatpak install -y --noninteractive "${origin:-flathub}" "$app" 2>/dev/null || true
        fi
      done < "$FLATPAK_STATE"
      echo "${GREEN}[✓] Flatpak applications verified/installed.${RESET}"
    fi
  fi
fi

if [[ "$AUTO_INSTALL" != "true" && "$DRY_RUN" != "true" ]]; then
  read -r -p "${BOLD}Proceed with root power capping and dotfile configuration? [Y/n]: ${RESET}" PROCEED_INPUT
  PROCEED_INPUT="${PROCEED_INPUT:-Y}"
  if [[ ! "$PROCEED_INPUT" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "Configuration aborted by user."
    exit 0
  fi
fi

# ==============================================================================
# 2. System Hardware & Power Configuration (Root)
# ==============================================================================
# Note: PAM stacks (/etc/pam.d/) and biometric authentication are intentionally
# kept 100% stock to guarantee clean sleep/wake cycles, update stability, and
# zero lockout risks. Only power-capping configs are deployed to root.
echo ""
echo "${BOLD}${YELLOW}--- [2/6] System & Power Capping Configuration ---${RESET}"

if [[ -d "$REPO_DIR/system" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "    [DRY-RUN] Would deploy root power configuration:"
    echo "      - /etc/default/cpu-power-cap"
    echo "      - /usr/local/sbin/cpu-power-cap (chmod 755)"
    echo "      - /usr/local/sbin/cpu-power-stats (chmod 755)"
    echo "      - /etc/systemd/system/cpu-power-* (services & timers)"
    echo "      - Enable and start cpu-power-cap.timer and cpu-power-stats.timer"
  else
    echo "[+] Deploying root power-capping configs from system/..."
    
    if [[ -f "$REPO_DIR/system/etc/default/cpu-power-cap" ]]; then
      sudo mkdir -p /etc/default
      sudo cp -v "$REPO_DIR/system/etc/default/cpu-power-cap" /etc/default/
    fi

    if [[ -d "$REPO_DIR/system/usr/local/sbin" ]]; then
      sudo mkdir -p /usr/local/sbin
      sudo cp -v "$REPO_DIR/system/usr/local/sbin/"* /usr/local/sbin/
      sudo chmod 755 /usr/local/sbin/cpu-power-*
    fi

    if [[ -d "$REPO_DIR/system/etc/systemd/system" ]]; then
      sudo mkdir -p /etc/systemd/system
      sudo cp -v "$REPO_DIR/system/etc/systemd/system/"* /etc/systemd/system/
      
      echo "[+] Reloading systemd daemons and enabling power services..."
      sudo systemctl daemon-reload
      sudo systemctl enable --now cpu-power-cap.timer cpu-power-stats.timer cpu-power-cap.service
    fi
    echo "${GREEN}[✓] System power capping applied and active.${RESET}"
  fi
else
  echo "${YELLOW}[!] Warning: system/ directory not found in repository.${RESET}"
fi

# ==============================================================================
# 3. Hardware Groups Configuration
# ==============================================================================
echo ""
echo "${BOLD}${YELLOW}--- [3/6] Hardware Groups Configuration ---${RESET}"
echo "[+] Configuring serial & hardware permissions ('uucp', 'dialout')..."
for grp in uucp dialout; do
  if getent group "$grp" >/dev/null; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "    [DRY-RUN] Would add user '$USER' to group '$grp'"
    else
      sudo usermod -aG "$grp" "$USER"
    fi
  fi
done
echo "${GREEN}[✓] Hardware group permissions configured.${RESET}"

# ==============================================================================
# 4. User Dotfiles & Desktop Configuration (With Rollback Manifest)
# ==============================================================================
echo ""
echo "${BOLD}${YELLOW}--- [4/6] Desktop & Dotfiles Deployment ---${RESET}"

if [[ -d "$REPO_DIR/home" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "    [DRY-RUN] Would backup and restore the following dotfiles to $HOME:"
    (
      cd "$REPO_DIR/home"
      find . -type f | while read -r relpath; do
        echo "      ~/${relpath#./}"
      done
    )
  else
    mkdir -p "$BACKUP_DIR"
    MANIFEST="$BACKUP_DIR/manifest.txt"
    ROLLBACK_SCRIPT="$BACKUP_DIR/rollback.sh"
    echo "# Workstation Backup Manifest ($BACKUP_TS)" > "$MANIFEST"
    echo "# Generated automatically by setup.sh" >> "$MANIFEST"

    echo "[+] Backing up existing files and recording rollback manifest..."

    (
      cd "$REPO_DIR/home"
      find . -type f | while read -r relpath; do
        target_file="$HOME/${relpath#./}"
        target_dir="$(dirname "$target_file")"
        
        # If target exists and differs, record and backup
        if [[ -e "$target_file" || -L "$target_file" ]]; then
          if ! cmp -s "$relpath" "$target_file" 2>/dev/null; then
            backup_dest="$BACKUP_DIR/${relpath#./}"
            mkdir -p "$(dirname "$backup_dest")"
            cp -p "$target_file" "$backup_dest"
            printf "%s\t%s\n" "$target_file" "$backup_dest" >> "$MANIFEST"
          fi
        fi
        
        mkdir -p "$target_dir"
        cp -p --remove-destination "$relpath" "$target_file"
      done
    )

    # Generate executable rollback script
    cat << 'EOF' > "$ROLLBACK_SCRIPT"
#!/usr/bin/env bash
# ==============================================================================
# Workstation Configuration Rollback
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$SCRIPT_DIR/manifest.txt"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Error: Manifest $MANIFEST missing." >&2
  exit 1
fi

echo "Rolling back modified files from $SCRIPT_DIR..."
while IFS=$'\t' read -r orig backup; do
  [[ "$orig" =~ ^# ]] && continue
  [[ -z "$orig" || -z "$backup" ]] && continue
  if [[ -f "$backup" ]]; then
    mkdir -p "$(dirname "$orig")"
    cp -p --remove-destination "$backup" "$orig"
    echo "  [✓] Restored $orig"
  fi
done < "$MANIFEST"
echo "Rollback completed successfully."
EOF
    chmod +x "$ROLLBACK_SCRIPT"
    echo "${GREEN}[✓] Backup and rollback manifest created at: $BACKUP_DIR${RESET}"

    # Secure SSH directory and config permissions
    if [[ -d "$HOME/.ssh" ]]; then
      chmod 700 "$HOME/.ssh" 2>/dev/null || true
      [[ -f "$HOME/.ssh/config" ]] && chmod 600 "$HOME/.ssh/config" 2>/dev/null || true
    fi

    # Enable user ssh-agent.socket (standard Omarchy SSH mechanism)
    if systemctl --user is-system-running &>/dev/null || [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      echo "[+] Enabling systemd user ssh-agent.socket..."
      systemctl --user daemon-reload 2>/dev/null || true
      systemctl --user enable --now ssh-agent.socket 2>/dev/null || true
      systemctl --user set-environment SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket" 2>/dev/null || true
    fi

    # Make executables in .local/bin executable
    if [[ -d "$HOME/.local/bin" ]]; then
      chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
    fi

    # Ensure global gitignore is active
    if [[ -f "$HOME/.config/git/ignore" ]]; then
      git config --global core.excludesfile "$HOME/.config/git/ignore" 2>/dev/null || true
    fi

    # Ensure custom Hyprland keybindings take priority over preinstalled webapp binds
    if [[ -f "$HOME/.config/hypr/hyprland.lua" ]]; then
      sed -i 's/^-- omarchy_preinstalled_bindings = false/omarchy_preinstalled_bindings = false/' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null || true
    fi

    # Start EasyEffects background audio processing service if session is active
    if systemctl --user is-system-running &>/dev/null || [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      systemctl --user start 'app-easyeffects\x2dservice@autostart.service' 2>/dev/null || true
    fi

    echo "${GREEN}[✓] Dotfiles successfully restored from home/.${RESET}"
  fi
else
  echo "${YELLOW}[!] Warning: home/ directory not found in repository.${RESET}"
fi

# ==============================================================================
# 5. Agent Brain Linking (~/.agents) & Multi-Agent Bridges
# ==============================================================================
echo ""
echo "${BOLD}${YELLOW}--- [5/6] Agent Brain & Interoperability Linking ---${RESET}"

AGENT_SOURCE="$REPO_DIR/agent"
AGENT_TARGET="$HOME/.agents"

if [[ -d "$AGENT_SOURCE" ]]; then
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "    [DRY-RUN] Would link $AGENT_TARGET -> $AGENT_SOURCE"
    echo "    [DRY-RUN] Would link canonical rule bridges: AGENTS.md, CLAUDE.md, GEMINI.md, .cursorrules"
    echo "    [DRY-RUN] Would deploy Claude Code hooks to ~/.claude/settings.json"
    echo "    [DRY-RUN] Would deploy Antigravity CLI whitelist to ~/.gemini/antigravity-cli/settings.json"
  else
    echo "[+] Linking $AGENT_TARGET -> $AGENT_SOURCE..."
    mkdir -p "$BACKUP_DIR"
    if [[ -e "$AGENT_TARGET" && ! -L "$AGENT_TARGET" ]]; then
      mv "$AGENT_TARGET" "$BACKUP_DIR/agents-pre-link"
    fi
    ln -sfn "$AGENT_SOURCE" "$AGENT_TARGET"
    echo "${GREEN}[✓] ~/.agents linked to workstation/agent.${RESET}"

    # Interoperability symlinks
    echo "[+] Configuring Agent bridges (Cursor, Claude, Gemini, Canonical)..."
    ln -sfn "$AGENT_TARGET/AGENTS.md" "$HOME/.cursorrules"
    ln -sfn "$AGENT_TARGET/AGENTS.md" "$HOME/CLAUDE.md"
    ln -sfn "$AGENT_TARGET/AGENTS.md" "$HOME/GEMINI.md"
    ln -sfn "$AGENT_TARGET/AGENTS.md" "$HOME/AGENTS.md"

    # Claude Code settings bridge (Spaces agent-badge hooks)
    if [[ -f "$AGENT_SOURCE/integrations/claude-settings.json" ]]; then
      mkdir -p "$HOME/.claude"
      if [[ ! -f "$HOME/.claude/settings.json" ]]; then
        cp "$AGENT_SOURCE/integrations/claude-settings.json" "$HOME/.claude/settings.json"
        echo "${GREEN}[✓] Claude Code Spaces hooks installed at ~/.claude/settings.json.${RESET}"
      else
        python3 -c "
import json, sys
src, dst = sys.argv[1], sys.argv[2]
try:
    with open(src) as f: b = json.load(f)
    with open(dst) as f: t = json.load(f)
    for k, v in b.items():
        if k not in t or not t[k]: t[k] = v
        elif isinstance(v, dict) and isinstance(t[k], dict): t[k].update(v)
    with open(dst, 'w') as f: json.dump(t, f, indent=2)
except Exception: pass
" "$AGENT_SOURCE/integrations/claude-settings.json" "$HOME/.claude/settings.json" 2>/dev/null || true
        echo "${GREEN}[✓] Claude Code Spaces hooks merged into ~/.claude/settings.json.${RESET}"
      fi
    fi

    # Claude Code skills link if ~/.claude/skills exists
    if [[ -d "$HOME/.claude" ]]; then
      mkdir -p "$HOME/.claude/skills"
      for skill_dir in "$AGENT_SOURCE/skills/"*; do
        if [[ -d "$skill_dir" ]]; then
          skill_name="$(basename "$skill_dir")"
          ln -sfn "$skill_dir" "$HOME/.claude/skills/$skill_name"
        fi
      done
      echo "${GREEN}[✓] Claude Code skills bridged.${RESET}"
    fi

    # Antigravity CLI settings & Command Whitelist bridge
    if [[ -f "$AGENT_SOURCE/integrations/antigravity-settings.json" ]]; then
      mkdir -p "$HOME/.gemini/antigravity-cli"
      if [[ ! -f "$HOME/.gemini/antigravity-cli/settings.json" ]]; then
        cp "$AGENT_SOURCE/integrations/antigravity-settings.json" "$HOME/.gemini/antigravity-cli/settings.json"
        echo "${GREEN}[✓] Antigravity CLI settings & whitelist deployed to ~/.gemini/antigravity-cli/settings.json.${RESET}"
      else
        python3 -c "
import json, sys
src, dst = sys.argv[1], sys.argv[2]
try:
    with open(src) as f: b = json.load(f)
    with open(dst) as f: t = json.load(f)
    bp = b.get('permissions', {})
    tp = t.setdefault('permissions', {})
    for kind in ('allow', 'ask', 'deny'):
        existing = set(tp.get(kind, []))
        for item in bp.get(kind, []):
            if item not in existing:
                tp.setdefault(kind, []).append(item)
    with open(dst, 'w') as f: json.dump(t, f, indent=2)
except Exception: pass
" "$AGENT_SOURCE/integrations/antigravity-settings.json" "$HOME/.gemini/antigravity-cli/settings.json" 2>/dev/null || true
        echo "${GREEN}[✓] Antigravity CLI whitelist merged into ~/.gemini/antigravity-cli/settings.json.${RESET}"
      fi
    fi
  fi
fi

# ==============================================================================
# 6. Omarchy Native Integrations & Pinned Shell Plugins
# ==============================================================================
if command -v omarchy &>/dev/null; then
  echo ""
  echo "${BOLD}${YELLOW}--- [6/6] Omarchy Native Integrations & Plugins ---${RESET}"

  # Set balanced AC power profile
  if command -v omarchy-powerprofiles-set &>/dev/null; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "    [DRY-RUN] Would run: omarchy-powerprofiles-set ac balanced"
    else
      echo "[+] Setting AC power profile to balanced..."
      if omarchy-powerprofiles-set ac balanced 2>/dev/null; then
        echo "    [✓] AC power profile set to balanced."
      else
        echo "    ${YELLOW}[!] Advisory: AC power profile could not be set automatically.${RESET}"
      fi
    fi
  fi

  # Third-party plugins with commit pinning and opt-in safety
  SPACES_COMMIT="458852c88336722f61d8c67487bc03d4d3523893"
  POMO_COMMIT="475b130c9b38edbb9e5d61bc2c9cac546a788ac1"

  DO_PLUGINS="Y"
  if [[ "$AUTO_INSTALL" != "true" && "$DRY_RUN" != "true" ]]; then
    read -r -p "${BOLD}Install pinned third-party Omarchy shell plugins (Spaces & Pomodoro)? [Y/n]: ${RESET}" DO_PLUGINS
    DO_PLUGINS="${DO_PLUGINS:-Y}"
  fi

  if [[ "$DO_PLUGINS" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "    [DRY-RUN] Would install and pin Spaces plugin at $SPACES_COMMIT"
      echo "    [DRY-RUN] Would install and pin Pomodoro plugin at $POMO_COMMIT"
      echo "    [DRY-RUN] Would disable redundant omarchy.workspaces"
    else
      echo "[+] Installing and pinning Omarchy shell plugins..."
      
      # Spaces plugin
      if ! omarchy plugin list 2>/dev/null | grep -q "tornikegomareli.spaces"; then
        echo "    -> Adding Spaces plugin..."
        omarchy plugin add https://github.com/tornikegomareli/omarchy-spaces.git --enable --yes 2>/dev/null || true
      fi
      if [[ -d "$HOME/.config/omarchy/plugins/tornikegomareli.spaces" ]]; then
        git -C "$HOME/.config/omarchy/plugins/tornikegomareli.spaces" checkout -q "$SPACES_COMMIT" 2>/dev/null || true
        echo "    [✓] Spaces plugin pinned to verified commit ($SPACES_COMMIT)."
      fi

      # Pomodoro plugin
      if ! omarchy plugin list 2>/dev/null | grep -q "techywilbur.pomodoro"; then
        echo "    -> Adding Pomodoro plugin..."
        omarchy plugin add https://github.com/techywilbur/omarchy-pomodoro.git --enable --yes 2>/dev/null || true
      fi
      if [[ -d "$HOME/.config/omarchy/plugins/techywilbur.pomodoro" ]]; then
        git -C "$HOME/.config/omarchy/plugins/techywilbur.pomodoro" checkout -q "$POMO_COMMIT" 2>/dev/null || true
        echo "    [✓] Pomodoro plugin pinned to verified commit ($POMO_COMMIT)."
      fi

      omarchy plugin disable omarchy.workspaces 2>/dev/null || true
      echo "${GREEN}[✓] Omarchy native plugins configured and securely pinned.${RESET}"
    fi
  else
    echo "${YELLOW}[!] Skipping third-party Omarchy plugin installation.${RESET}"
  fi
fi

# ==============================================================================
# Post-Install Action Checklist
# ==============================================================================
echo ""
echo "${BOLD}${GREEN}=== Setup Complete ===${RESET}"
echo ""
echo "${BOLD}Important Post-Install Verification & Steps:${RESET}"
echo "  1. ${BOLD}TRIM on LUKS2 (If newly formatted SSD):${RESET}"
echo "     sudo cryptsetup refresh --allow-discards --persistent root"
echo ""
echo "  2. ${BOLD}SSH Authentication:${RESET}"
echo "     ssh-add ~/.ssh/id_ed25519 (ssh-agent.socket is active)"
echo ""
echo "  3. ${BOLD}Restart Session:${RESET}"
echo "     Log out and log back in to apply hardware group changes ('uucp') and Hyprland bindings."
echo ""
echo "  4. ${BOLD}Shell Architecture:${RESET}"
echo "     Foot terminal launches Zsh directly with size 13 font."
echo "     System login shell is intentionally preserved as Bash to safeguard Omarchy OS stability."
echo ""
if [[ "$DRY_RUN" != "true" && -d "$BACKUP_DIR" ]]; then
  echo "  5. ${BOLD}Rollback Utility:${RESET}"
  echo "     If needed, revert all dotfile changes with: $BACKUP_DIR/rollback.sh"
  echo ""
fi
