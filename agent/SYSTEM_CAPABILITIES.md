# Workstation System Capabilities & Toolchain Inventory

This manifest catalogs all discovered developer runtimes, search utilities, and CLI tools on the workstation running Omarchy 4 (Arch Linux + Hyprland). The agent uses this inventory to select the most efficient binary for any given operation.

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
| **`rg` (ripgrep)** | `/usr/bin/rg` | Sub-second regex codebase search; replaces slow grep |
| **`fd` (fd-find)** | `~/.local/bin/fd` or `/usr/bin/fd` | Fast file traversal; replaces slow find commands |
| **`jq`** | `/usr/bin/jq` | Deterministic JSON filtering & schema validation |
| **`tree`** | `/usr/bin/tree` | High-level directory topology snapshots |
| **`eza`** | `/usr/bin/eza` | Modern ls with file metadata and tree view |
| **`fzf`** | `/usr/bin/fzf` | Command-line fuzzy matching |
| **`glow`** | `/usr/bin/glow` | Terminal Markdown formatting and inspection |
| **`micro`** | `/usr/bin/micro` | Terminal editor |
| **`zoxide`** | `/usr/bin/zoxide` | Fast directory jumping |

---

## 3. Hardware & Embedded Tooling (pipx)

- **esptool** (5.6.0)
- **platformio** (6.2.0)

---

## 4. Workstation Package Ecosystem (Omarchy 4 / Arch Linux)

Refer to [`state/pacman-explicit.txt`](../state/pacman-explicit.txt), [`state/flatpak.txt`](../state/flatpak.txt), and [`state/omarchy-plugins.txt`](../state/omarchy-plugins.txt).
Key system packages:
- `linux-omarchy` (Kernel)
- `hyprland` & `uwsm` (Wayland compositor & session)
- `foot` (Terminal)
- `pipewire` & `wireplumber` (Audio routing & sinks)
- `easyeffects` (Realtek ALC256 auto-gain)
- `thermald` & `cpu-power-cap` (RAPL thermal limiter)
- `zram-generator` (In-memory zstd compression)
- `tailscale` (Encrypted mesh VPN)
- Developer toolchains: `zsh`, `omarchy-zsh`, `micro`, `tree`, `eza`, `fzf`, `zoxide`, `ripgrep`, `fd`, `jq`, `starship`
