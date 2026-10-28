#!/usr/bin/env bash
# ==============================================================================
# Omarchy Package & Capability Scanner (scan_capabilities.sh)
# Scans installed Pacman/Yay packages, runtimes, and local binaries.
# Updates ~/.agents/SYSTEM_CAPABILITIES.md only when tool changes are detected.
# ==============================================================================

set -euo pipefail

OUTPUT_FILE="$HOME/.agents/SYSTEM_CAPABILITIES.md"
TEMP_FILE="/tmp/SYSTEM_CAPABILITIES.tmp"

# Ensure complete PATH and environment for detection
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$HOME/Android/Sdk/platform-tools:$HOME/Work/google-cloud-sdk/bin:$HOME/.local/bin:$PATH"

# Gather runtimes safely without SIGPIPE failures
NODE_VER=$(node -v 2>/dev/null || echo "Not detected")
NPM_VER=$(npm -v 2>/dev/null || echo "Not detected")
PYTHON_VER=$(python3 --version 2>/dev/null || echo "Not detected")
JAVA_VER=$(java -version 2>&1 | awk 'NR==1' || echo "Not detected")
ADB_VER=$(adb --version 2>/dev/null | awk 'NR==1' || echo "Not detected")
GCLOUD_VER=$(gcloud --version 2>/dev/null | awk 'NR==1' || echo "Not detected")
ESPTOOL_VER=$(esptool.py version 2>/dev/null || echo "Not detected")
PIO_VER=$(pio --version 2>/dev/null | echo "Not detected")

cat <<EOF > "$TEMP_FILE"
# Omarchy System Capabilities & Toolchain Inventory

This manifest catalogs all discovered developer runtimes, search utilities, and CLI tools on Omarchy Linux (Arch + Hyprland). The agent uses this inventory to select the most efficient binary for any given operation.

---

## 1. Core Runtimes & SDKs

| Runtime / Tool | Version Detected | Primary Agent Utility |
| :--- | :--- | :--- |
| **Node.js** | \`$NODE_VER\` | Next.js server & CMS builds |
| **npm** | \`$NPM_VER\` | Package dependency management |
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
| **\`fd\`** | $(which fd 2>/dev/null || echo "missing") | Fast file traversal; replaces slow find commands |
| **\`jq\`** | $(which jq 2>/dev/null || echo "missing") | Deterministic JSON filtering & schema validation |
| **\`tree\`** | $(which tree 2>/dev/null || echo "missing") | High-level directory topology snapshots |
| **\`eza\`** | $(which eza 2>/dev/null || echo "missing") | Modern ls with file metadata and tree view |
| **\`fzf\`** | $(which fzf 2>/dev/null || echo "missing") | Command-line fuzzy matching |
| **\`micro\`** | $(which micro 2>/dev/null || echo "missing") | Terminal text editor |
| **\`zoxide\`** | $(which zoxide 2>/dev/null || echo "missing") | Fast directory jumping |

---

## 3. Notable Explicitly Installed System Packages (Pacman)

EOF

if command -v pacman &>/dev/null; then
  pacman -Qqe 2>/dev/null | sort | awk '{print "- `" $1 "`"}' >> "$TEMP_FILE"
fi

# Only overwrite if content has actually changed
if [ ! -f "$OUTPUT_FILE" ] || ! cmp -s "$TEMP_FILE" "$OUTPUT_FILE"; then
  mv "$TEMP_FILE" "$OUTPUT_FILE"
  echo "[✓] System capabilities updated: $OUTPUT_FILE"
else
  rm -f "$TEMP_FILE"
  echo "[*] System capabilities unchanged."
fi
