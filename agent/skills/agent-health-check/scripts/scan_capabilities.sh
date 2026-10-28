#!/usr/bin/env bash
# ==============================================================================
# WSL Package & Capability Scanner (scan_capabilities.sh)
# Scans installed APT packages, pipx CLIs, runtimes, and local binaries.
# Updates ~/.agents/SYSTEM_CAPABILITIES.md only when tool changes are detected.
# ==============================================================================

set -euo pipefail

OUTPUT_FILE="$HOME/.agents/SYSTEM_CAPABILITIES.md"
TEMP_FILE="/tmp/SYSTEM_CAPABILITIES.tmp"

# Ensure complete PATH and environment for detection
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$HOME/.local/share/fnm:$HOME/Android/Sdk/platform-tools:$HOME/Work/google-cloud-sdk/bin:$HOME/.local/bin:$PATH"
if [ ! -d "${XDG_RUNTIME_DIR:-}" ]; then
  export XDG_RUNTIME_DIR="/tmp/runtime-$USER"
  mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null
fi
eval "$("$HOME/.local/share/fnm/fnm" env --shell bash 2>/dev/null)" 2>/dev/null || true

# Gather runtimes safely without SIGPIPE failures
NODE_VER=$(node -v 2>/dev/null || echo "Not detected")
NPM_VER=$(npm -v 2>/dev/null || echo "Not detected")
PYTHON_VER=$(python3 --version 2>/dev/null || echo "Not detected")
JAVA_VER=$(java -version 2>&1 | awk 'NR==1' || echo "Not detected")
ADB_VER=$(adb --version 2>/dev/null | awk 'NR==1' || echo "Not detected")
GCLOUD_VER=$(gcloud --version 2>/dev/null | awk 'NR==1' || echo "Not detected")
ESPTOOL_VER=$(esptool version 2>/dev/null | awk 'NR==1' || echo "Not detected")
PIO_VER=$(pio --version 2>/dev/null | awk 'NR==1' || echo "Not detected")

cat <<EOF > "$TEMP_FILE"
# WSL System Capabilities & Toolchain Inventory

This manifest catalogs all discovered developer runtimes, search utilities, and CLI tools on WSL2 Ubuntu. The agent uses this inventory to select the most efficient binary for any given operation.

---

## 1. Core Runtimes & SDKs

| Runtime / Tool | Version Detected | Primary Agent Utility |
| :--- | :--- | :--- |
| **Node.js (fnm)** | \`$NODE_VER\` | Next.js server & CMS builds |
| **npm (fnm)** | \`$NPM_VER\` | Package dependency management |
| **Python** | \`$PYTHON_VER\` | Embedded scripts & tool execution |
| **Java / OpenJDK** | \`$JAVA_VER\` | Android Gradle build compilation |
| **Android SDK (adb)**| \`$ADB_VER\` | Real-device & emulator user verification |
| **Google Cloud SDK** | \`$GCLOUD_VER\` | GCP service account & project inspection |
| **PlatformIO (pio)** | \`$PIO_VER\` | ESP32 firmware build, upload & monitor |
| **esptool.py** | \`$ESPTOOL_VER\` | Direct ESP32 ROM bootloader flashing |

---

## 2. High-Performance CLI Utilities

| Binary | Location | Agent Operation Benefit |
| :--- | :--- | :--- |
| **\`rg\` (ripgrep)** | $(which rg 2>/dev/null || echo "missing") | Sub-second regex codebase search; replaces slow grep |
| **\`fd\` (fd-find)** | $(which fd 2>/dev/null || echo "missing") | Fast file traversal; replaces slow find commands |
| **\`jq\`** | $(which jq 2>/dev/null || echo "missing") | Deterministic JSON filtering & schema validation |
| **\`tree\`** | $(which tree 2>/dev/null || echo "missing") | High-level directory topology snapshots |
| **\`eza\`** | $(which eza 2>/dev/null || echo "missing") | Modern ls with file metadata and tree view |
| **\`fzf\`** | $(which fzf 2>/dev/null || echo "missing") | Command-line fuzzy matching |
| **\`glow\`** | $(which glow 2>/dev/null || echo "missing") | Terminal Markdown formatting and inspection |
| **\`micro\`** | $(which micro 2>/dev/null || echo "missing") | Terminal editor |
| **\`zoxide\`** | $(which zoxide 2>/dev/null || echo "missing") | Fast directory jumping |

---

## 3. Hardware & Embedded Tooling (pipx)

EOF

if command -v pipx &>/dev/null; then
  pipx list --short 2>/dev/null | awk '{print "- **" $1 "** (" $2 ")"}' >> "$TEMP_FILE"
else
  echo "- pipx not found" >> "$TEMP_FILE"
fi

cat <<EOF >> "$TEMP_FILE"

---

## 4. Notable Manually Installed Packages (APT)

EOF

apt-mark showmanual 2>/dev/null | sort | awk '{print "- `" $1 "`"}' >> "$TEMP_FILE"

# Only overwrite if content has actually changed
if [ ! -f "$OUTPUT_FILE" ] || ! cmp -s "$TEMP_FILE" "$OUTPUT_FILE"; then
  mv "$TEMP_FILE" "$OUTPUT_FILE"
  echo "[✓] System capabilities updated: $OUTPUT_FILE"
else
  rm -f "$TEMP_FILE"
  echo "[*] System capabilities unchanged."
fi
