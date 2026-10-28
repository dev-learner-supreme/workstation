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
# 1. Package Installation Guidance (Manual via Omarchy / Pacman)
# ==============================================================================
echo "${BOLD}${YELLOW}--- [1/5] Package Installation Guidance ---${RESET}"
echo "In accordance with your policy, package installations should be verified"
echo "and executed via Omarchy or Pacman directly."
echo ""
echo "Recorded explicit pacman packages:  ${BOLD}$(wc -l < "$REPO_DIR/state/pacman-explicit.txt" 2>/dev/null || echo '0')${RESET} packages"
echo "Recorded Flatpak applications:      ${BOLD}$(wc -l < "$REPO_DIR/state/flatpak.txt" 2>/dev/null || echo '0')${RESET} apps"
echo ""
echo "${BLUE}Commands for manual package review & install:${RESET}"
echo "  ${BOLD}Pacman packages:${RESET}  sudo pacman -S --needed - < \"$REPO_DIR/state/pacman-explicit.txt\""
echo "  ${BOLD}Foreign/AUR:${RESET}      yay -S --needed - < \"$REPO_DIR/state/pacman-foreign.txt\""
echo "  ${BOLD}Omarchy packages:${RESET} omarchy package install <package-name>"
echo ""

if [[ "${1:-}" != "--auto" && "${1:-}" != "-y" ]]; then
  read -r -p "${BOLD}Proceed with system and dotfile configuration? [Y/n]: ${RESET}" PROCEED_INPUT
  PROCEED_INPUT="${PROCEED_INPUT:-Y}"
  if [[ ! "$PROCEED_INPUT" =~ ^[Yy]([Ee][Ss])?$ ]]; then
    echo "Configuration aborted by user."
    exit 0
  fi
fi

# ==============================================================================
# 2. System Hardware & Power Configuration (Root)
# ==============================================================================
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
  fi

  # Make executables in .local/bin executable
  if [[ -d "$HOME/.local/bin" ]]; then
    chmod +x "$HOME/.local/bin/"* 2>/dev/null || true
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
  echo "[+] Configuring Cursor & Claude Code bridges..."
  ln -sfn "$AGENT_TARGET/AGENTS.md" "$HOME/.cursorrules"
  ln -sfn "$AGENT_TARGET/AGENTS.md" "$HOME/CLAUDE.md"

  # Claude Code settings bridge (Spaces agent-badge hooks)
  if [[ -f "$AGENT_SOURCE/integrations/claude-settings.json" ]]; then
    mkdir -p "$HOME/.claude"
    if [[ ! -f "$HOME/.claude/settings.json" ]]; then
      cp "$AGENT_SOURCE/integrations/claude-settings.json" "$HOME/.claude/settings.json"
      echo "${GREEN}[✓] Claude Code Spaces hooks installed at ~/.claude/settings.json.${RESET}"
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
