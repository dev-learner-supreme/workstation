#!/usr/bin/env bash
# ==============================================================================
# Workstation Unified Sync Script
# Snapshots dotfiles, system power caps, package manifests, and AI agent intelligence
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Ensure authorship attribution
git config user.name "Arun Rao Balappa"
git config user.email "arunraobalappa@gmail.com"

# ------------------------------------------------------------------------------
# 1. Snapshot User Dotfiles ($HOME -> home/)
# ------------------------------------------------------------------------------
home_files=(
  .bashrc
  .zshrc
  .ssh/config
  .config/foot/foot.ini
  .config/hypr/bindings.lua
  .config/hypr/input.lua
  .config/hypr/looknfeel.lua
  .config/environment.d/ssh_auth_socket.conf
  .config/environment.d/ssh-agent.conf
  .config/environment.d/flatpak.conf
  .config/autostart/easyeffects-service.desktop
  .config/easyeffects/db/easyeffectsrc
  .config/wireplumber/wireplumber.conf.d/60-output-priority.conf
  .local/share/wireplumber/scripts/output-priority-reset.lua
  .config/pipewire/swiftgo-speaker-eq.conf.keep
  .config/omarchy/shell.json
  .local/state/omarchy/powerprofiles/ac
  .local/bin/airplane-mode-toggle
  .local/share/applications/android-studio.desktop
  .config/git/ignore
)

home_dirs=(
  .local/share/easyeffects/output
  .local/share/easyeffects/autoload
)

for f in "${home_files[@]}"; do
  if [[ -e "$HOME/$f" ]]; then
    mkdir -p "home/$(dirname "$f")"
    cp -p "$HOME/$f" "home/$f"
  fi
done

for d in "${home_dirs[@]}"; do
  if [[ -d "$HOME/$d" ]]; then
    mkdir -p "home/$(dirname "$d")"
    cp -rp "$HOME/$d" "home/$d"
  fi
done

# ------------------------------------------------------------------------------
# 2. Snapshot Root System Configs (/ -> system/)
# ------------------------------------------------------------------------------
system_files=(
  /etc/default/cpu-power-cap
  /usr/local/sbin/cpu-power-cap
  /usr/local/sbin/cpu-power-stats
  /etc/systemd/system/cpu-power-cap.service
  /etc/systemd/system/cpu-power-cap.timer
  /etc/systemd/system/cpu-power-stats.service
  /etc/systemd/system/cpu-power-stats.timer
)

for f in "${system_files[@]}"; do
  if [[ -r "$f" ]]; then
    mkdir -p "system$(dirname "$f")"
    cp -p "$f" "system$f"
  fi
done

# ------------------------------------------------------------------------------
# 3. Snapshot Package & Plugin State (Arch / Omarchy)
# ------------------------------------------------------------------------------
mkdir -p state
if command -v pacman &>/dev/null; then
  pacman -Qqe > state/pacman-explicit.txt 2>/dev/null || true
  pacman -Qqem > state/pacman-foreign.txt 2>/dev/null || true
fi

if command -v flatpak &>/dev/null; then
  flatpak list --app --columns=application,origin > state/flatpak.txt 2>/dev/null || true
fi

if command -v omarchy &>/dev/null; then
  omarchy plugin list > state/omarchy-plugins.txt 2>/dev/null || true
  { omarchy version 2>/dev/null || true; uname -r; } > state/versions.txt 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 4. Synchronize Agent Intelligence
# ------------------------------------------------------------------------------
# If ~/.agents is NOT a symlink to agent/, sync any changes into agent/
if [[ -d "$HOME/.agents" && ! -L "$HOME/.agents" ]]; then
  rsync -av --exclude='.git' "$HOME/.agents/" "$REPO_DIR/agent/"
fi

# ------------------------------------------------------------------------------
# 5. Security Scanner (Refuse commit if secret-like pattern matches)
# ------------------------------------------------------------------------------
SECRET_PATTERN='-----BEGIN [A-Z ]*PRIVATE KEY-----|"(accessToken|refreshToken)"|gh[pousr]_[A-Za-z0-9]{30,}|sk-ant-[A-Za-z0-9_-]{20,}|AIzaSy[A-Za-z0-9_-]{33}'

if grep -rIlE --exclude-dir='.git' -e "$SECRET_PATTERN" home system state agent 2>/dev/null; then
  echo "[!] Security Warning: Possible secret or API key detected in staged files." >&2
  echo "    Aborting commit. Clean credentials before syncing." >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# 6. Commit & Push
# ------------------------------------------------------------------------------
git add -A

if git diff --cached --quiet; then
  echo "[*] Workstation state clean. No changes to commit."
else
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
  git commit -m "sync(workstation): snapshot system, dotfiles, and agent ($TIMESTAMP)" -m "$(git diff --cached --stat | tail -1)"
  echo "[✓] Local workstation snapshot committed ($TIMESTAMP)."
fi

# Push if requested or upstream configured
if [[ "${1:-}" == "--push" ]] || git remote get-url origin &>/dev/null; then
  if git push -u origin main 2>/dev/null; then
    echo "[✓] Successfully pushed to $(git remote get-url origin)."
  else
    echo "[!] Remote push skipped (network unavailable or remote not ready)."
  fi
fi
