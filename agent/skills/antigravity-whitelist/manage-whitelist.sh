#!/usr/bin/env bash
# ==============================================================================
# Antigravity CLI Whitelist Manager
# Inspect, add, and synchronize command execution permissions.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

LIVE_CONFIG="$HOME/.gemini/antigravity-cli/settings.json"
REPO_CONFIG="$REPO_DIR/agent/integrations/antigravity-settings.json"

action="${1:-list}"

case "$action" in
  list)
    echo "=== Antigravity CLI Allowed Commands ==="
    target_file="$LIVE_CONFIG"
    [[ ! -f "$target_file" ]] && target_file="$REPO_CONFIG"
    if [[ -f "$target_file" ]]; then
      python3 -c "
import json, sys
with open('$target_file') as f:
    cfg = json.load(f)
for cmd in cfg.get('permissions', {}).get('allow', []):
    print(f'  ✓ {cmd}')
"
    else
      echo "  No configuration found."
    fi
    ;;

  allow)
    cmd="${2:-}"
    if [[ -z "$cmd" ]]; then
      echo "Usage: $0 allow <command-prefix>" >&2
      exit 1
    fi
    rule="command($cmd)"
    python3 -c "
import json, os
live = '$LIVE_CONFIG'
repo = '$REPO_CONFIG'
rule = '$rule'

def add_rule(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    cfg = {}
    if os.path.exists(path):
        try:
            with open(path) as f: cfg = json.load(f)
        except Exception: pass
    perms = cfg.setdefault('permissions', {})
    allow = perms.setdefault('allow', [])
    if rule not in allow:
        allow.append(rule)
        with open(path, 'w') as f: json.dump(cfg, f, indent=2)
        print(f'Added {rule} -> {path}')
    else:
        print(f'{rule} already present in {path}')

add_rule(live)
add_rule(repo)
"
    ;;

  sync)
    echo "[+] Synchronizing Antigravity whitelist..."
    python3 -c "
import json, os
live = '$LIVE_CONFIG'
repo = '$REPO_CONFIG'

if os.path.exists(live):
    os.makedirs(os.path.dirname(repo), exist_ok=True)
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
    with open(live, 'w') as f: json.dump(r, f, indent=2)
    print('Synchronized and deduplicated whitelist across live and repository.')
elif os.path.exists(repo):
    os.makedirs(os.path.dirname(live), exist_ok=True)
    with open(repo) as f: r = json.load(f)
    with open(live, 'w') as f: json.dump(r, f, indent=2)
    print('Seeded live configuration from repository baseline.')
"
    ;;

  *)
    echo "Usage: $0 {list|allow <cmd>|sync}" >&2
    exit 1
    ;;
esac
