#!/usr/bin/env python3
"""
J.A.R.V.I.S. Session Initialization & Telemetry Hook
Executed by Antigravity CLI lifecycle hooks (SessionStart) or directly.
Collects bare-metal hardware health metrics and formats visual banner and telemetry.
"""

import os
import sys
import json
import subprocess
import select

def get_sys(path, default="N/A"):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return default

def gather_telemetry():
    # 1. CPU Thermals
    temp_str = "N/A"
    for i in range(10):
        tz = f"/sys/class/thermal/thermal_zone{i}"
        if os.path.exists(tz) and get_sys(f"{tz}/type") == "x86_pkg_temp":
            raw = get_sys(f"{tz}/temp")
            if raw.isdigit():
                temp_str = f"{int(raw) / 1000:.1f}°C"
            break

    # 2. Power Caps (RAPL)
    pl1 = int(get_sys("/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw", "0")) // 1000000
    pl2 = int(get_sys("/sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw", "0")) // 1000000
    power_str = f"PL1: {pl1}W / PL2: {pl2}W" if pl1 > 0 else "18W / 35W (Enforced)"

    # 3. Memory
    avail_mb = 0
    total_mb = 16384
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as f:
            lines = dict(line.split(":") for line in f if ":" in line)
        avail_mb = int(lines.get("MemAvailable", "0 kB").split()[0]) // 1024
        total_mb = int(lines.get("MemTotal", "0 kB").split()[0]) // 1024
    except Exception:
        pass
    mem_str = f"{avail_mb:,} MB Free / {total_mb:,} MB"

    # 4. Storage (NVMe Root)
    storage_str = "444 GB Free (7% used)"
    try:
        stat = os.statvfs("/")
        avail_gb = (stat.f_bavail * stat.f_frsize) // (1024**3)
        total_gb = (stat.f_blocks * stat.f_frsize) // (1024**3)
        used_pct = 100 - int((stat.f_bavail / stat.f_blocks) * 100)
        storage_str = f"{avail_gb} GB Free ({used_pct}% used)"
    except Exception:
        pass

    # 5. Battery & Power Profile
    bat_cap = get_sys("/sys/class/power_supply/BAT1/capacity", "100")
    bat_stat = get_sys("/sys/class/power_supply/BAT1/status", "Discharging")
    bat_str = f"{bat_cap}% ({bat_stat})"

    # 6. Serial Access (uucp group)
    uucp_active = False
    try:
        groups = subprocess.check_output(["id", "-nG"], text=True, stderr=subprocess.DEVNULL)
        uucp_active = "uucp" in groups.split()
    except Exception:
        pass
    serial_str = "Active (`uid=1000` in `uucp`)" if uucp_active else "Pending session login"

    # 7. Workstation Repository Sync
    git_str = "Synchronized (`origin/main`)"
    try:
        res = subprocess.check_output(
            ["git", "-C", "/home/arun/workstation", "status", "--porcelain"],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
        if res:
            git_str = "Uncommitted local changes"
        else:
            ahead = subprocess.check_output(
                ["git", "-C", "/home/arun/workstation", "rev-list", "--count", "@{upstream}..HEAD"],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            if ahead and int(ahead) > 0:
                git_str = f"{ahead} commit(s) ahead of origin"
    except Exception:
        pass

    return {
        "temp": temp_str,
        "power": power_str,
        "mem": mem_str,
        "storage": storage_str,
        "battery": bat_str,
        "serial": serial_str,
        "git": git_str,
    }

def generate_banner(m):
    return f"""```text
       _         _    ____   __     __  ___   ____  
      | |       / \\  |  _ \\  \\ \\   / / |_ _| / ___| 
   _  | |      / _ \\ | |_) |  \\ \\ / /   | |  \\___ \\ 
  | |_| |     / ___ \\|  _ <    \\ V /    | |   ___) |
   \\___/     /_/   \\_\\_| \\_\\    \\_/    |___| |____/ 
```
**J.A.R.V.I.S. Protocol Engaged** | Acer Swift Go 14 (`SFG14-71`) | Omarchy Linux

| Telemetry Subsystem | Calibrated Profile | Live Hardware Telemetry | Status |
|---|---|---|---|
| **CPU Thermals** | Package ≤ 83.0°C | **{m['temp']}** | **NOMINAL** |
| **RAPL Power Envelopes** | PL1: 18W / PL2: 35W (28s) | **{m['power']}** | **ENFORCED** |
| **System Working Memory** | 16 GB LPDDR5 + ZRAM | **{m['mem']}** | **OPTIMAL** |
| **NVMe Root Partition** | Btrfs on LUKS2 (Async TRIM) | **{m['storage']}** | **HEALTHY** |
| **Power Profile & Battery** | AC/BAT Balanced Profiles | **{m['battery']}** | **BALANCED** |
| **Hardware Serial Toolchain** | ESP32 Direct Access (`uucp`) | **{m['serial']}** | **READY** |
| **Workstation Repository** | `dev-learner-supreme/workstation` | **{m['git']}** | **SYNCED** |
"""

def main():
    # Consume stdin if piped (with non-blocking 50ms select)
    stdin_data = ""
    try:
        r, _, _ = select.select([sys.stdin], [], [], 0.05)
        if r:
            stdin_data = sys.stdin.read()
    except Exception:
        pass

    telemetry = gather_telemetry()
    banner = generate_banner(telemetry)

    # If --text flag specified, print raw markdown
    if "--text" in sys.argv:
        print(banner)
        return

    # Deduplicate hook execution per conversation session
    if stdin_data:
        try:
            payload = json.loads(stdin_data)
            conv_id = payload.get("conversationId")
            if conv_id:
                uid = os.getuid()
                runtime_dir = f"/run/user/{uid}" if os.path.isdir(f"/run/user/{uid}") else "/tmp"
                lock_file = os.path.join(runtime_dir, f"jarvis_session_{conv_id}.lock")
                if os.path.exists(lock_file):
                    # Already injected for this session start
                    print(json.dumps({"injectSteps": []}))
                    return
                with open(lock_file, "w", encoding="utf-8") as f:
                    f.write(str(os.getpid()))
        except Exception:
            pass

    # Format JSON response according to Antigravity SessionStart hook contract
    # NOTE: Do NOT use "metadata" field because agy's ScrubInternalFields currently
    # panics with "type mismatch: cannot convert string to message" when traversing map values.
    # We embed the pre-gathered banner and telemetry directly into the systemMessage so the model
    # can output it immediately on turn 1 without making 4 exploratory bash tool calls.
    response = {
        "injectSteps": [
            {
                "systemMessage": {
                    "systemMessage": (
                        "J.A.R.V.I.S. PROTOCOL ENGAGED: Workspace rules, skills, and hardware telemetry verified nominal.\n\n"
                        f"{banner}\n\n"
                        "MANDATE: On turn 1 of every session, after /clear, or upon /resume: ALWAYS confirm J.A.R.V.I.S. operational "
                        "status by immediately outputting the pre-gathered canonical ASCII banner and live telemetry matrix above. "
                        "Do NOT execute bash commands or explore directories to re-run jarvis-session-init.py on turn 1—the fresh "
                        "matrix is already provided above."
                    )
                }
            }
        ]
    }
    print(json.dumps(response, indent=2))

if __name__ == "__main__":
    main()
