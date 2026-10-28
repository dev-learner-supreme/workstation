#!/usr/bin/env bash
# ==============================================================================
# Workstation Unified Sync Script
# Snapshots dotfiles, system power caps, package manifests, and AI agent intelligence
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Ensure authorship attribution
if [[ "$(git config user.name 2>/dev/null)" != "Arun Rao Balappa" ]]; then
  git config user.name "Arun Rao Balappa" 2>/dev/null || true
fi
if [[ "$(git config user.email 2>/dev/null)" != "arunraobalappa@gmail.com" ]]; then
  git config user.email "arunraobalappa@gmail.com" 2>/dev/null || true
fi

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
  pacman -Qqen > state/pacman-explicit.txt 2>/dev/null || true
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
# 4. Synchronize Agent Intelligence & Command Whitelist
# ------------------------------------------------------------------------------
# If ~/.agents is NOT a symlink to agent/, sync any changes into agent/
if [[ -d "$HOME/.agents" && ! -L "$HOME/.agents" ]]; then
  rsync -av --exclude='.git' "$HOME/.agents/" "$REPO_DIR/agent/"
fi

# Capture Antigravity CLI whitelist & permissions
if [[ -f "$HOME/.gemini/antigravity-cli/settings.json" ]]; then
  mkdir -p "$REPO_DIR/agent/integrations"
  python3 -c "
import json, os, sys
live = os.path.expanduser('~/.gemini/antigravity-cli/settings.json')
repo = '$REPO_DIR/agent/integrations/antigravity-settings.json'
try:
    with open(live) as f: l = json.load(f)
    r = {}
    if os.path.exists(repo):
        with open(repo) as f: r = json.load(f)
    lp = l.get('permissions', {})
    rp = r.setdefault('permissions', {})
    for k in ('allow', 'ask', 'deny'):
        merged = sorted(list(set(lp.get(k, []) + rp.get(k, []))))
        rp[k] = merged
    with open(repo, 'w') as f: json.dump(r, f, indent=2)
except Exception: pass
" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 5. Selective Staging & Security Diff Scanner
# ------------------------------------------------------------------------------
# Explicitly stage known repository targets (avoiding accidental root pollution)
git add home system state agent README.md setup.sh sync.sh .gitignore

# Comprehensive secret pattern detection
SECRET_PATTERN='-----BEGIN [A-Z ]*PRIVATE KEY-----|"(accessToken|refreshToken|client_secret|apiKey|api_key|password)"|gh[pousr]_[A-Za-z0-9]{30,}|sk-ant-[A-Za-z0-9_-]{20,}|AIzaSy[A-Za-z0-9_-]{33}|xox[baprs]-[A-Za-z0-9]{10,}|glpat-[A-Za-z0-9_-]{20,}'

# Fail-closed secret scanner with explicit pattern flag (-e)
STAGED_DIFF="$(git diff --cached)"
if [[ -n "$STAGED_DIFF" ]]; then
  scanner_status=0
  echo "$STAGED_DIFF" | grep -q -E -e "$SECRET_PATTERN" || scanner_status=$?
  if [[ "$scanner_status" -eq 0 ]]; then
    echo "[!] Security Warning: Possible secret, private key, or credential detected in staged changes." >&2
    echo "    Aborting commit. Staged diff matched secret scanner patterns." >&2
    git reset -q HEAD --
    exit 1
  elif [[ "$scanner_status" -gt 1 ]]; then
    echo "[!] Security Error: Secret scanner failed with error code $scanner_status." >&2
    echo "    Aborting commit to prevent accidental credential leak (fail-closed)." >&2
    git reset -q HEAD --
    exit 1
  fi
fi

# ------------------------------------------------------------------------------
# 6. Commit & Push
# ------------------------------------------------------------------------------
if git diff --cached --quiet; then
  echo "[*] Workstation state clean. No changes to commit."
else
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
  git commit -m "sync(workstation): snapshot system, dotfiles, and agent ($TIMESTAMP)" -m "$(git diff --cached --stat | tail -1)"
  echo "[✓] Local workstation snapshot committed ($TIMESTAMP)."
fi

# Push only if explicitly requested
if [[ "${1:-}" == "--push" ]]; then
  if git push -u origin main 2>/dev/null; then
    echo "[✓] Successfully pushed to $(git remote get-url origin)."
  else
    echo "[!] Remote push skipped (network unavailable or remote not ready)."
  fi
fi
