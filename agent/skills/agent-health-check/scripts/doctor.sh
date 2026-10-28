#!/usr/bin/env bash
# ==============================================================================
# Agent Health Diagnostic Script (doctor.sh)
# Performs deterministic, multi-point health check across 5 operational pillars
# ==============================================================================

set -u

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

check_pass() {
  echo "  [PASS] $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

check_warn() {
  echo "  [WARN] $1"
  WARN_COUNT=$((WARN_COUNT + 1))
}

check_fail() {
  echo "  [FAIL] $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "================================================================================"
echo " AGENT & ENVIRONMENT HEALTH DIAGNOSTIC AUDIT"
echo " Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo " Machine: $(uname -srm)"
echo "================================================================================"

# Refresh system capabilities inventory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/scan_capabilities.sh" ]; then
  "$SCRIPT_DIR/scan_capabilities.sh" &>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 1. TOOLCHAINS & RUNTIMES
# ------------------------------------------------------------------------------
echo ""
echo "1. Toolchains & Runtimes:"

# Check Node runtime (via mise, fnm, or native system nodejs)
NODE_VER=""
if command -v node &>/dev/null; then
  NODE_VER=$(node -v 2>/dev/null || echo "")
elif [ -d "$HOME/.local/share/fnm" ] || command -v fnm &>/dev/null; then
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$("$HOME/.local/share/fnm/fnm" env 2>/dev/null)" 2>/dev/null || true
  NODE_VER=$(node -v 2>/dev/null || echo "")
fi

if [ -n "$NODE_VER" ]; then
  check_pass "Node runtime active: $NODE_VER"
else
  check_fail "Node runtime missing (install nodejs or mise activate)"
fi

# Check esptool & pio
if command -v esptool.py &>/dev/null || [ -f "$HOME/.local/bin/esptool.py" ]; then
  check_pass "esptool.py active in ~/.local/bin"
else
  check_warn "esptool.py missing from ~/.local/bin"
fi

if command -v pio &>/dev/null || [ -f "$HOME/.local/bin/pio" ]; then
  check_pass "PlatformIO (pio) active in ~/.local/bin"
else
  check_warn "pio missing from ~/.local/bin"
fi

# Check Android SDK & adb
if command -v adb &>/dev/null || [ -f "$HOME/Android/Sdk/platform-tools/adb" ]; then
  check_pass "Android SDK platform-tools active (adb)"
else
  check_warn "Android SDK platform-tools (adb) not found"
fi

# Check CLI utilities
for tool in rg fd jq tree; do
  if command -v "$tool" &>/dev/null || [ -f "$HOME/.local/bin/$tool" ]; then
    check_pass "CLI utility installed: $tool"
  else
    check_warn "CLI utility missing: $tool"
  fi
done

# ------------------------------------------------------------------------------
# 2. CONTEXT, RULES & MEMORY INTEGRITY
# ------------------------------------------------------------------------------
echo ""
echo "2. Context, Rules & Memory Integrity:"

AGENTS_FILE="$HOME/.agents/AGENTS.md"
if [ -f "$AGENTS_FILE" ]; then
  BYTES=$(wc -c < "$AGENTS_FILE" | tr -d ' ')
  if [ "$BYTES" -lt 20000 ]; then
    check_pass "AGENTS.md size ($BYTES bytes) well within 24KB limit"
  else
    check_warn "AGENTS.md size ($BYTES bytes) approaching 24KB budget"
  fi
else
  check_fail "Master AGENTS.md missing from ~/.agents/"
fi

# Check MEMORY.md pruning threshold
MEMORY_FILE="$HOME/.agents/MEMORY.md"
if [ -f "$MEMORY_FILE" ]; then
  LINES=$(wc -l < "$MEMORY_FILE" | tr -d ' ')
  if [ "$LINES" -lt 250 ]; then
    check_pass "MEMORY.md length ($LINES lines) within 250-line pruning threshold"
  else
    check_warn "MEMORY.md length ($LINES lines) exceeds 250 lines; pruning recommended"
  fi
else
  check_warn "MEMORY.md missing from ~/.agents/"
fi

# Check canonical symlinks deduplication
CANONICAL_TARGET=$(realpath "$AGENTS_FILE" 2>/dev/null || echo "")
DUPS=0
for sym in "$HOME/AGENTS.md" "$HOME/GEMINI.md" "$HOME/CLAUDE.md" "$HOME/.cursorrules" "$HOME/.agents/rules/AGENTS.md"; do
  if [ -L "$sym" ]; then
    TARGET=$(realpath "$sym" 2>/dev/null || echo "")
    if [ "$TARGET" = "$CANONICAL_TARGET" ]; then
      DUPS=$((DUPS + 1))
    fi
  fi
done

if [ "$DUPS" -ge 4 ]; then
  check_pass "Rule symlinks deduplicated ($DUPS verified pointing to canonical AGENTS.md)"
else
  check_warn "Only $DUPS/5 expected symlinks point to canonical AGENTS.md"
fi

# ------------------------------------------------------------------------------
# 3. PRIVACY & ORG AIRGAP AUDIT
# ------------------------------------------------------------------------------
echo ""
echo "3. Privacy & Org Airgap Audit (Math-Junior Repos):"

GLOBAL_EXCLUDES=$(git config --global core.excludesfile || echo "")
if [ -n "$GLOBAL_EXCLUDES" ] && [ -f "$GLOBAL_EXCLUDES" ]; then
  check_pass "Global gitignore active ($GLOBAL_EXCLUDES)"
else
  check_warn "Global gitignore not configured or missing"
fi

LEAK_DETECTED=0
for repo in "$HOME/Work/ProjectAgri" "$HOME/Work/CMS" "$HOME/Work/RODO-Website" "$HOME/Work/Firebase"; do
  if [ -d "$repo/.git" ]; then
    REPO_NAME=$(basename "$repo")
    # Check if .agents or MEMORY.md tracked
    if git -C "$repo" ls-files --error-unmatch .agents MEMORY.md .cursorrules 2>/dev/null; then
      check_fail "Private agent files tracked in org repo: $REPO_NAME"
      LEAK_DETECTED=1
    else
      check_pass "Clean airgap: $REPO_NAME has no tracked private agent files"
    fi
  fi
done

# ------------------------------------------------------------------------------
# 4. REMOTE SYNC & DISASTER RECOVERY
# ------------------------------------------------------------------------------
echo ""
echo "4. Remote Sync & Disaster Recovery:"

if [ -d "$HOME/.agents/.git" ] || git -C "$HOME/.agents" rev-parse --is-inside-work-tree &>/dev/null; then
  check_pass "~/.agents repository tracked and active"
  REMOTE_URL=$(git -C "$HOME/.agents" remote get-url origin 2>/dev/null || echo "")
  if [ -n "$REMOTE_URL" ]; then
    check_pass "Private remote linked: $REMOTE_URL"
  else
    check_warn "No remote origin configured in ~/.agents"
  fi

  # Check working tree cleanliness
  if git -C "$HOME/.agents" diff-index --quiet HEAD -- 2>/dev/null; then
    check_pass "Working directory is clean (all rules committed)"
  else
    check_warn "Uncommitted changes exist in repository"
  fi
else
  check_fail "~/.agents is not tracked by Git"
fi

# ------------------------------------------------------------------------------
# 5. WORKSTATION HARDWARE & RESOURCE HEADROOM
# ------------------------------------------------------------------------------
echo ""
echo "5. Workstation Hardware & Resource Headroom:"

FREE_RAM=$(free -m 2>/dev/null | awk '/^Mem:/{print $7}' || echo "0")
TOTAL_RAM=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
if [ "$FREE_RAM" -gt 1500 ]; then
  check_pass "Available RAM: ${FREE_RAM}MB / ${TOTAL_RAM}MB (Safe headroom)"
else
  check_warn "Low available RAM: ${FREE_RAM}MB / ${TOTAL_RAM}MB (Starvation risk)"
fi

# Check root NVMe SSD capacity (using robust NF offset to handle anonymous mounts)
ROOT_AVAIL=$(df -h / 2>/dev/null | awk 'NR==2 {print $(NF-2)}' || echo "unknown")
ROOT_SIZE=$(df -h / 2>/dev/null | awk 'NR==2 {print $(NF-4)}' || echo "unknown")
ROOT_USE_PCT=$(df -h / 2>/dev/null | awk 'NR==2 {print $(NF-1)}' | tr -d '%' || echo "0")
if [ "${ROOT_USE_PCT:-0}" -lt 85 ]; then
  check_pass "NVMe Root SSD (/): ${ROOT_AVAIL} available / ${ROOT_SIZE} (${ROOT_USE_PCT}% used)"
else
  check_warn "NVMe Root SSD (/) constrained: ${ROOT_AVAIL} available / ${ROOT_SIZE} (${ROOT_USE_PCT}% used)"
fi

# ------------------------------------------------------------------------------
# FINAL TELEMETRY SCORE
# ------------------------------------------------------------------------------
echo ""
echo "================================================================================"
echo " HEALTH AUDIT SUMMARY: $PASS_COUNT PASSED | $WARN_COUNT WARNINGS | $FAIL_COUNT FAILURES"
if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
  echo " OVERALL STATUS: OPTIMAL (100% System Fidelity)"
elif [ "$FAIL_COUNT" -eq 0 ]; then
  echo " OVERALL STATUS: HEALTHY (Minor advisory warnings)"
else
  echo " OVERALL STATUS: ATTENTION REQUIRED"
fi
echo "================================================================================"
