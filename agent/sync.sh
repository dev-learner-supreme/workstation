#!/usr/bin/env bash
# ==============================================================================
# Agent Sync Script
# Forwards to the unified workstation sync script
# ==============================================================================

set -euo pipefail

if [[ -f "$HOME/workstation/sync.sh" ]]; then
  exec "$HOME/workstation/sync.sh" "$@"
fi

# Fallback to local git sync if standalone
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
git add -A
git commit -m "sync(agents): update rules, skills, and memory ($(date '+%Y-%m-%d %H:%M:%S'))" || true
git push origin main 2>/dev/null || true
