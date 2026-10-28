# WSL System Capabilities & Toolchain Inventory

This manifest catalogs all discovered developer runtimes, search utilities, and CLI tools on WSL2 Ubuntu. The agent uses this inventory to select the most efficient binary for any given operation.

---

## 1. Core Runtimes & SDKs

| Runtime / Tool | Version Detected | Primary Agent Utility |
| :--- | :--- | :--- |
| **Node.js (fnm)** | `v24.22.1` | Next.js server & CMS builds |
| **npm (fnm)** | `11.19.1` | Package dependency management |
| **Python** | `Python 3.14.4` | Embedded scripts & tool execution |
| **Java / OpenJDK** | `openjdk version "25.0.4.1" 2026-08-18` | Android Gradle build compilation |
| **Android SDK (adb)**| `Android Debug Bridge version 1.0.41` | Real-device & emulator user verification |
| **Google Cloud SDK** | `Google Cloud SDK 590.0.1` | GCP service account & project inspection |
| **PlatformIO (pio)** | `PlatformIO Core, version 6.2.0` | ESP32 firmware build, upload & monitor |
| **esptool.py** | `esptool v5.6.0` | Direct ESP32 ROM bootloader flashing |

---

## 2. High-Performance CLI Utilities

| Binary | Location | Agent Operation Benefit |
| :--- | :--- | :--- |
| **`rg` (ripgrep)** | /usr/bin/rg | Sub-second regex codebase search; replaces slow grep |
| **`fd` (fd-find)** | /home/arun/.local/bin/fd | Fast file traversal; replaces slow find commands |
| **`jq`** | /usr/bin/jq | Deterministic JSON filtering & schema validation |
| **`tree`** | /usr/bin/tree | High-level directory topology snapshots |
| **`eza`** | /usr/bin/eza | Modern ls with file metadata and tree view |
| **`fzf`** | /usr/bin/fzf | Command-line fuzzy matching |
| **`glow`** | /usr/bin/glow | Terminal Markdown formatting and inspection |
| **`micro`** | /usr/bin/micro | Terminal editor |
| **`zoxide`** | /usr/bin/zoxide | Fast directory jumping |

---

## 3. Hardware & Embedded Tooling (pipx)

- **esptool** (5.6.0)
- **platformio** (6.2.0)

---

## 4. Notable Manually Installed Packages (APT)

- `bash`
- `build-essential`
- `coreutils`
- `coreutils-from-uutils`
- `curl`
- `dash`
- `diffutils`
- `dpkg`
- `eza`
- `fd-find`
- `findutils`
- `fzf`
- `gh`
- `git`
- `glow`
- `gnu-coreutils`
- `grep`
- `gzip`
- `hostname`
- `hwdata`
- `init`
- `jq`
- `keychain`
- `libattr1`
- `linux-tools-virtual`
- `micro`
- `ncurses-base`
- `ncurses-bin`
- `openjdk-25-jdk`
- `pipx`
- `python3-pip`
- `python3-venv`
- `ripgrep`
- `rust-coreutils`
- `tar`
- `tree`
- `ubuntu-minimal`
- `ubuntu-wsl`
- `unzip`
- `util-linux`
- `zoxide`
- `zsh`
- `zsh-autosuggestions`
- `zsh-syntax-highlighting`
