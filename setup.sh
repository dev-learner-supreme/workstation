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

echo "${BOLD}${BLUE}=== Workstation Restoration & Configuration ===${RESET}"
echo "Repository: $REPO_DIR"
echo "Timestamp:  $(date)"
echo ""

# Prevent running directly as root
if [[ "$EUID" -eq 0 ]]; then
  echo "${RED}[!] Please run setup.sh as your standard user, not as root.${RESET}"
  echo "    The script will invoke sudo when root privileges are required."
  exit 1
fi

# Request sudo upfront
sudo -v || { echo "${RED}[!] Sudo authentication failed.${RESET}"; exit 1; }

# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

# ==============================================================================
# 1. Package Installation (Pacman & Flatpak)
# ==============================================================================
echo "${BOLD}${YELLOW}--- [1/5] Package Installation ---${RESET}"
PACMAN_STATE="$REPO_DIR/state/pacman-explicit.txt"
FOREIGN_STATE="$REPO_DIR/state/pacman-foreign.txt"
FLATPAK_STATE="$REPO_DIR/state/flatpak.txt"

AUTO_INSTALL=false
if [[ "${1:-}" == "--auto" || "${1:-}" == "-y" ]]; then
  AUTO_INSTALL=true
fi

# Pacman packages
if [[ -f "$PACMAN_STATE" && -s "$PACMAN_STATE" ]]; then
  pkg_count="$(wc -l < "$PACMAN_STATE")"
  echo "Recorded explicit pacman packages: ${BOLD}$pkg_count${RESET}"

  DO_PACMAN="Y"
  if [[ "$AUTO_INSTALL" != "true" ]]; then
    read -r -p "${BOLD}Install recorded pacman packages now via sudo pacman? [Y/n]: ${RESET}" DO_PACMAN
    DO_PACMAN="${DO_PACMAN:-Y}"
  fi

  if [[ "$DO_PACMAN" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "[+] Installing explicit pacman packages..."
    sudo pacman -S --needed --noconfirm - < "$PACMAN_STATE"
    echo "${GREEN}[✓] Pacman packages installed successfully.${RESET}"
  else
    echo "${YELLOW}[!] Skipping pacman package installation.${RESET}"
  fi
fi

# Foreign / AUR packages
if [[ -f "$FOREIGN_STATE" && -s "$FOREIGN_STATE" ]]; then
  if command -v yay &>/dev/null; then
    echo "[+] Installing AUR packages via yay..."
    yay -S --needed --noconfirm - < "$FOREIGN_STATE"
    echo "${GREEN}[✓] AUR packages installed successfully.${RESET}"
  else
    echo "${YELLOW}[!] 'yay' not found; please install AUR packages manually:${RESET}"
    echo "    yay -S --needed - < \"$FOREIGN_STATE\""
  fi
fi

# Flatpak applications
if [[ -f "$FLATPAK_STATE" && -s "$FLATPAK_STATE" ]] && command -v flatpak &>/dev/null; then
  flatpak_count="$(wc -l < "$FLATPAK_STATE")"
  echo "Recorded Flatpak applications: ${BOLD}$flatpak_count${RESET}"
  
  DO_FLATPAK="Y"
  if [[ "$AUTO_INSTALL" != "true" ]]; then
    read -r -p "${BOLD}Install recorded Flatpak applications? [Y/n]: ${RESET}" DO_FLATPAK
    DO_FLATPAK="${DO_FLATPAK:-Y}"
  fi

  if [[ "$DO_FLATPAK" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "[+] Ensuring flathub remote is configured..."
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    while IFS=$'\t' read -r app origin; do
      [[ -z "$app" ]] && continue
      echo "[+] Installing flatpak: $app..."
      flatpak install -y "${origin:-flathub}" "$app" 2>/dev/null || true
    done < "$FLATPAK_STATE"
    echo "${GREEN}[✓] Flatpak applications installed.${RESET}"
  fi
fi

if [[ "$AUTO_INSTALL" != "true" ]]; then
  read -r -p "${BOLD}Proceed with system power capping and dotfile configuration? [Y/n]: ${RESET}" PROCEED_INPUT
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
echo "${BOLD}${YELLOW}--- [2/5] System & Power Capping Configuration ---${RESET}"

# Copy system files to /
if [[ -d "$REPO_DIR/system" ]]; then
  echo "[+] Deploying root power-capping configs from system/..."
  
  if [[ -f "$REPO_DIR/system/etc/default/cpu-power-cap" ]]; then
    sudo mkdir -p /etc/default
    sudo cp -v "$REPO_DIR/system/etc/default/cpu-power-cap" /etc/default/
  fi

  if [[ -d "$REPO_DIR/system/usr/local/sbin" ]]; then
    sudo mkdir -p /usr/local/sbin
    sudo cp -v "$REPO_DIR/system/usr/local/sbin/"* /usr/local/sbin/
    sudo chmod 755 /usr/local/sbin/cpu-power-* 2>/dev/null || true
  fi

  if [[ -d "$REPO_DIR/system/etc/systemd/system" ]]; then
    sudo mkdir -p /etc/systemd/system
    sudo cp -v "$REPO_DIR/system/etc/systemd/system/"* /etc/systemd/system/
    
    echo "[+] Reloading systemd daemons and enabling power services..."
    sudo systemctl daemon-reload || true
    sudo systemctl enable --now cpu-power-cap.timer cpu-power-stats.timer cpu-power-cap.service || true
  fi
  echo "${GREEN}[✓] System power capping applied.${RESET}"
else
  echo "${YELLOW}[!] Warning: system/ directory not found in repository.${RESET}"
fi

# ==============================================================================
# 3. Hardware Groups Configuration
# ==============================================================================
echo ""
echo "${BOLD}${YELLOW}--- [3/5] Hardware Groups Configuration ---${RESET}"
echo "[+] Adding user '$USER' to 'uucp' (ESP32/Arduino) and 'dialout'..."
for grp in uucp dialout; do
  if getent group "$grp" >/dev/null; then
    sudo usermod -aG "$grp" "$USER" || true
  fi
done
echo "${GREEN}[✓] Hardware group permissions configured.${RESET}"

# ==============================================================================
# 4. User Dotfiles & Desktop Configuration
# ==============================================================================
echo ""
echo "${BOLD}${YELLOW}--- [4/5] Desktop & Dotfiles Deployment ---${RESET}"

if [[ -d "$REPO_DIR/home" ]]; then
  mkdir -p "$BACKUP_DIR"
  echo "[+] Backing up existing conflicting files to $BACKUP_DIR..."

  # Copy home files with backup
  (
    cd "$REPO_DIR/home"
    find . -type f | while read -r relpath; do
      target_file="$HOME/${relpath#./}"
      target_dir="$(dirname "$target_file")"
      
      # If target exists and differs, backup
      if [[ -f "$target_file" ]] && ! cmp -s "$relpath" "$target_file"; then
        mkdir -p "$BACKUP_DIR/$(dirname "${relpath#./}")"
        cp -p "$target_file" "$BACKUP_DIR/${relpath#./}"
      fi
      
      mkdir -p "$target_dir"
      cp -p --remove-destination "$relpath" "$target_file"
    done
  )

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

  echo "${GREEN}[✓] Dotfiles successfully restored from home/.${RESET}"
else
  echo "${YELLOW}[!] Warning: home/ directory not found in repository.${RESET}"
fi

# ==============================================================================
# 5. Agent Brain Linking (~/.agents) & Multi-Agent Bridges
# ==============================================================================
echo ""
echo "${BOLD}${YELLOW}--- [5/5] Agent Brain & Interoperability Linking ---${RESET}"

AGENT_SOURCE="$REPO_DIR/agent"
AGENT_TARGET="$HOME/.agents"

if [[ -d "$AGENT_SOURCE" ]]; then
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
      # Safely merge hooks into existing settings.json without losing user preferences
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
    echo "${GREEN}[✓] Agent skills bridged to Claude Code.${RESET}"
  fi
fi

# ==============================================================================
# Post-Install Action Checklist
# ==============================================================================
echo ""
echo "${BOLD}${GREEN}=== Setup Complete ===${RESET}"
echo ""
echo "${BOLD}Important One-Time Manual Steps (Run as needed):${RESET}"
echo "  1. ${BOLD}TRIM on LUKS2:${RESET}"
echo "     sudo cryptsetup refresh --allow-discards --persistent root"
echo ""
echo "  2. ${BOLD}Omarchy Spaces Plugin:${RESET}"
echo "     omarchy plugin add https://github.com/tornikegomareli/omarchy-spaces.git --enable"
echo "     omarchy plugin disable omarchy.workspaces"
echo ""
echo "  3. ${BOLD}Power Profile (AC Balanced):${RESET}"
echo "     omarchy-powerprofiles-set ac balanced"
echo ""
echo "  4. ${BOLD}SSH Authentication:${RESET}"
echo "     ssh-add ~/.ssh/id_ed25519 (ssh-agent.socket enabled automatically)"
echo ""
echo "  5. ${BOLD}Restart Session:${RESET}"
echo "     Log out and log back in to apply group changes ('uucp') and Hyprland bindings."
echo ""
echo "  6. ${BOLD}Shell & Terminal Architecture:${RESET}"
echo "     Foot terminal launches Zsh directly with size 13 font."
echo "     System login shell is intentionally preserved as Bash to safeguard Omarchy OS stability."
echo ""
