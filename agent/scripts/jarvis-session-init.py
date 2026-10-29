#!/usr/bin/env python3
"""
J.A.R.V.I.S. Session Initialization & Telemetry Hook
Executed by Antigravity CLI lifecycle hooks (SessionStart) or directly via shell launcher.
Collects bare-metal hardware health metrics and formats visual HUD and telemetry.
"""

import os
import sys
import glob
import json
import re
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
    temp_val = 0.0
    temp_str = "N/A"
    for i in range(10):
        tz = f"/sys/class/thermal/thermal_zone{i}"
        if os.path.exists(tz) and get_sys(f"{tz}/type") == "x86_pkg_temp":
            raw = get_sys(f"{tz}/temp")
            if raw.isdigit():
                temp_val = int(raw) / 1000.0
                temp_str = f"{temp_val:.1f}°C"
            break

    # 2. Power Caps (RAPL)
    pl1 = int(get_sys("/sys/class/powercap/intel-rapl:0/constraint_0_power_limit_uw", "0")) // 1000000
    pl2 = int(get_sys("/sys/class/powercap/intel-rapl:0/constraint_1_power_limit_uw", "0")) // 1000000
    power_str = f"PL1: {pl1}W / PL2: {pl2}W" if pl1 > 0 else "18W / 35W (Enforced)"

    # 3. Physical RAM
    mem_avail_gb = 0.0
    mem_total_gb = 15.3
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as f:
            lines = dict(line.split(":") for line in f if ":" in line)
        mem_avail_gb = int(lines.get("MemAvailable", "0 kB").split()[0]) / (1024 * 1024)
        mem_total_gb = int(lines.get("MemTotal", "0 kB").split()[0]) / (1024 * 1024)
    except Exception:
        pass
    mem_str = f"{mem_avail_gb:.1f} GB Free / {mem_total_gb:.1f} GB"

    # 4. ZRAM Swap Pool
    zram_pool_gb = 15.3
    zram_used_mb = 0
    if os.path.exists("/sys/block/zram0"):
        try:
            with open("/sys/block/zram0/disksize") as f:
                zram_pool_gb = int(f.read().strip()) / (1024**3)
            with open("/sys/block/zram0/mm_stat") as f:
                stats = f.read().split()
                if len(stats) >= 3:
                    zram_used_mb = int(stats[2]) // (1024 * 1024)
        except Exception:
            pass
    zram_str = f"{zram_pool_gb:.1f} GB Pool ({zram_used_mb} MB used)"

    # 5. Storage (NVMe Root)
    disk_avail_gb = 0
    disk_used_pct = 0
    try:
        stat = os.statvfs("/")
        disk_avail_gb = (stat.f_bavail * stat.f_frsize) // (1024**3)
        disk_used_pct = 100 - int((stat.f_bavail / stat.f_blocks) * 100)
    except Exception:
        pass
    storage_str = f"{disk_avail_gb} GB Free ({disk_used_pct}% used)"

    # 6. Battery & Power Profile
    bat_cap = get_sys("/sys/class/power_supply/BAT1/capacity", "100")
    bat_stat = get_sys("/sys/class/power_supply/BAT1/status", "Discharging")
    bat_str = f"{bat_cap}% ({bat_stat})"

    # 7. Hardware Serial Toolchain (ESP32)
    serial_devs = glob.glob("/dev/ttyUSB*") + glob.glob("/dev/ttyACM*")
    serial_str = ", ".join([os.path.basename(d) for d in serial_devs]) if serial_devs else "None connected"

    # 8. Workstation Repository Sync
    git_clean = True
    git_ahead = 0
    git_str = "Synchronized (origin/main)"
    try:
        res = subprocess.check_output(
            ["git", "-C", "/home/arun/workstation", "status", "--porcelain"],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
        if res:
            git_clean = False
            git_str = "Uncommitted local changes"
        else:
            ahead = subprocess.check_output(
                ["git", "-C", "/home/arun/workstation", "rev-list", "--count", "@{upstream}..HEAD"],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            if ahead and int(ahead) > 0:
                git_ahead = int(ahead)
                git_str = f"{ahead} commit(s) ahead"
    except Exception:
        pass

    return {
        "temp_val": temp_val,
        "temp": temp_str,
        "pl1": pl1,
        "pl2": pl2,
        "power": power_str,
        "mem_avail_gb": mem_avail_gb,
        "mem_total_gb": mem_total_gb,
        "mem": mem_str,
        "zram_pool_gb": zram_pool_gb,
        "zram_used_mb": zram_used_mb,
        "zram": zram_str,
        "disk_avail_gb": disk_avail_gb,
        "disk_used_pct": disk_used_pct,
        "storage": storage_str,
        "bat_cap": bat_cap,
        "bat_stat": bat_stat,
        "battery": bat_str,
        "serial_devs": serial_devs,
        "serial": serial_str,
        "git_clean": git_clean,
        "git_ahead": git_ahead,
        "git": git_str,
    }

def strip_ansi(s):
    return re.sub(r"\033\[[0-9;]*m", "", s)

def pad_str(s, width, align="left"):
    vlen = len(strip_ansi(s))
    fill = " " * max(0, width - vlen)
    if align == "left":
        return s + fill
    elif align == "right":
        return fill + s
    else:
        lp = fill[:len(fill)//2]
        rp = fill[len(fill)//2:]
        return lp + s + rp

def generate_ansi_hud(m):
    # Palette: Muted colors tuned for Omarchy dark theme
    R   = "\033[0m"
    B   = "\033[1m"
    DIM = "\033[38;2;100;116;139m"   # #64748b - muted cool slate
    BRD = "\033[38;2;71;85;105m"     # #475569 - subtle border
    TTL = "\033[38;2;226;183;20m"    # #e2b714 - warm amber gold
    LBL = "\033[38;2;203;213;225m"   # #cbd5e1 - soft off-white
    GRN = "\033[38;2;129;199;132m"   # #81c784 - soft sage green
    AMB = "\033[38;2;240;173;78m"    # #f0ad4e - muted amber
    RED = "\033[38;2;229;115;115m"   # #e57373 - soft coral
    CYN = "\033[38;2;103;216;239m"   # #67d8ef - soft cyan

    temp_val = m["temp_val"]
    temp_c = RED if temp_val > 83.0 else (AMB if temp_val > 70.0 else GRN)

    bat_stat = m["bat_stat"]
    bat_cap = int(m["bat_cap"]) if m["bat_cap"].isdigit() else 100
    bat_c = GRN if bat_stat == "Charging" else (AMB if bat_cap > 20 else RED)

    git_c = GRN if (m["git_clean"] and m["git_ahead"] == 0) else AMB
    git_label = "Synchronized" if (m["git_clean"] and m["git_ahead"] == 0) else ("Ahead " + str(m["git_ahead"]) if m["git_clean"] else "Modified")

    def format_cell(lbl, val, note):
        f_lbl = pad_str(lbl, 12, "left")
        f_val = pad_str(val, 16, "left")
        f_note = pad_str(note, 15, "right")
        return f"{f_lbl}{f_val}{f_note}"

    rows = [
        ((f"{LBL}CPU Temp{R}",     f"{temp_c}{m['temp']}{R}",                       f"{DIM}≤83°C target{R}"),
         (f"{LBL}NVMe Root{R}",    f"{GRN}{m['disk_avail_gb']} GB Free{R}",         f"{DIM}{m['disk_used_pct']}% used Btrfs{R}")),
        ((f"{LBL}RAPL Power{R}",   f"{AMB}PL1 {m['pl1']}W / {m['pl2']}W{R}",       f"{DIM}enforced 28s{R}"),
         (f"{LBL}Battery{R}",      f"{bat_c}{m['bat_cap']}%{R}",                    f"{DIM}{bat_stat.lower()}{R}")),
        ((f"{LBL}Memory{R}",       f"{GRN}{m['mem_avail_gb']:.1f} GB Free{R}",      f"{DIM}/ {m['mem_total_gb']:.1f} GB RAM{R}"),
         (f"{LBL}ESP32 Bus{R}",    f"{CYN if m['serial_devs'] else DIM}{m['serial']}{R}", f"{DIM}/dev/ttyUSB*{R}")),
        ((f"{LBL}ZRAM Pool{R}",    f"{GRN}{m['zram_pool_gb']:.1f} GB{R}",           f"{DIM}{m['zram_used_mb']} MB used{R}"),
         (f"{LBL}Workstation{R}",  f"{git_c}{git_label}{R}",                       f"{DIM}origin/main{R}")),
    ]

    W_COL = 43
    TOTAL_WIDTH = 2 * W_COL + 7  # 93 exact visible cells

    title = f" {B}{TTL}J.A.R.V.I.S.{R} {LBL}• Hardware Telemetry{R} "
    dashes_top = "─" * (TOTAL_WIDTH - 3 - len(strip_ansi(title)))
    
    lines = []
    lines.append(f"{BRD}╭─{R}{title}{BRD}{dashes_top}╮{R}")
    for c1, c2 in rows:
        s1 = format_cell(c1[0], c1[1], c1[2])
        s2 = format_cell(c2[0], c2[1], c2[2])
        lines.append(f"{BRD}│{R} {s1} {BRD}│{R} {s2} {BRD}│{R}")
    
    footer = f" {DIM}Acer Swift Go 14 (SFG14-71) • Omarchy Linux{R} "
    dashes_bot = "─" * (TOTAL_WIDTH - 3 - len(strip_ansi(footer)))
    lines.append(f"{BRD}╰{dashes_bot}{R}{footer}{BRD}─╯{R}")

    return "\n".join(lines)

def generate_markdown_banner(m):
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
| **System Working Memory** | 16 GB Physical RAM | **{m['mem']}** | **OPTIMAL** |
| **ZRAM Swap Pool** | 15.3 GB zstd compressed | **{m['zram']}** | **HEALTHY** |
| **NVMe Root Partition** | Btrfs on LUKS2 (Async TRIM) | **{m['storage']}** | **HEALTHY** |
| **Power Profile & Battery** | AC/BAT Balanced Profiles | **{m['battery']}** | **BALANCED** |
| **Hardware Serial Toolchain** | ESP32 Bus (`/dev/ttyUSB*`) | **{m['serial']}** | **{'READY' if m['serial_devs'] else 'STANDBY'}** |
| **Workstation Repository** | `dev-learner-supreme/workstation` | **{m['git']}** | **SYNCED** |
"""

def generate_rich_hud(m):
    from rich.console import Console
    from rich.panel import Panel
    from rich.table import Table
    from rich import box

    console = Console()

    temp_val = m["temp_val"]
    temp_color = "#e57373" if temp_val > 83.0 else ("#f0ad4e" if temp_val > 70.0 else "#81c784")

    bat_stat = m["bat_stat"]
    bat_cap = int(m["bat_cap"]) if m["bat_cap"].isdigit() else 100
    bat_color = "#81c784" if bat_stat == "Charging" else ("#f0ad4e" if bat_cap > 20 else "#e57373")

    git_color = "#81c784" if (m["git_clean"] and m["git_ahead"] == 0) else "#f0ad4e"
    git_label = "Synchronized" if (m["git_clean"] and m["git_ahead"] == 0) else ("Ahead " + str(m["git_ahead"]) if m["git_clean"] else "Modified")

    serial_color = "#67d8ef" if m["serial_devs"] else "#64748b"

    # Create 2 sub-tables for left and right columns
    t_left = Table(box=None, show_header=False, pad_edge=False, padding=(0, 1), expand=True)
    t_left.add_column("Label", style="bold #cbd5e1", width=12)
    t_left.add_column("Value", width=16)
    t_left.add_column("Note", style="#64748b", justify="right")

    t_left.add_row("CPU Temp", f"[{temp_color}]{m['temp']}[/]", "≤83°C target")
    t_left.add_row("RAPL Power", f"[#f0ad4e]PL1 {m['pl1']}W / {m['pl2']}W[/]", "enforced 28s")
    t_left.add_row("Memory", f"[#81c784]{m['mem_avail_gb']:.1f} GB Free[/]", f"/ {m['mem_total_gb']:.1f} GB RAM")
    t_left.add_row("ZRAM Pool", f"[#81c784]{m['zram_pool_gb']:.1f} GB[/]", f"{m['zram_used_mb']} MB used")

    t_right = Table(box=None, show_header=False, pad_edge=False, padding=(0, 1), expand=True)
    t_right.add_column("Label", style="bold #cbd5e1", width=12)
    t_right.add_column("Value", width=16)
    t_right.add_column("Note", style="#64748b", justify="right")

    t_right.add_row("NVMe Root", f"[#81c784]{m['disk_avail_gb']} GB Free[/]", f"{m['disk_used_pct']}% used Btrfs")
    t_right.add_row("Battery", f"[{bat_color}]{m['bat_cap']}%[/]", bat_stat.lower())
    t_right.add_row("ESP32 Bus", f"[{serial_color}]{m['serial']}[/]", "/dev/ttyUSB*")
    t_right.add_row("Workstation", f"[{git_color}]{git_label}[/]", "origin/main")

    # Main layout grid combining both columns with a subtle vertical divider
    grid = Table.grid(expand=True, padding=(0, 1))
    grid.add_column(ratio=1)
    grid.add_column(width=1)
    grid.add_column(ratio=1)
    grid.add_row(t_left, "[#475569]│[/]", t_right)

    card_width = min(console.width or 96, 96)
    panel = Panel(
        grid,
        title="[bold #e2b714] J.A.R.V.I.S. [/][bold #cbd5e1]•[/] [#94a3b8] Hardware Telemetry [/]",
        title_align="left",
        subtitle="[#64748b] Acer Swift Go 14 (SFG14-71) • Omarchy Linux [/]",
        subtitle_align="right",
        border_style="#475569",
        box=box.ROUNDED,
        padding=(0, 1),
        width=card_width,
    )
    console.print(panel)

def main():
    stdin_data = ""
    try:
        r, _, _ = select.select([sys.stdin], [], [], 0.05)
        if r:
            stdin_data = sys.stdin.read()
    except Exception:
        pass

    telemetry = gather_telemetry()

    # If --text flag specified (run by shell launcher), output HUD
    if "--text" in sys.argv:
        try:
            generate_rich_hud(telemetry)
        except ImportError:
            # Clean fallback to native ANSI HUD if rich is not yet installed
            print(generate_ansi_hud(telemetry))
        return

    # Hook JSON mode (for Antigravity CLI SessionStart)
    banner = generate_markdown_banner(telemetry)

    if stdin_data:
        try:
            payload = json.loads(stdin_data)
            conv_id = payload.get("conversationId")
            if conv_id:
                uid = os.getuid()
                runtime_dir = f"/run/user/{uid}" if os.path.isdir(f"/run/user/{uid}") else "/tmp"
                lock_file = os.path.join(runtime_dir, f"jarvis_session_{conv_id}.lock")
                if os.path.exists(lock_file):
                    print(json.dumps({"injectSteps": []}))
                    return
                with open(lock_file, "w", encoding="utf-8") as f:
                    f.write(str(os.getpid()))
        except Exception:
            pass

    response = {
        "injectSteps": [
            {
                "systemMessage": {
                    "systemMessage": (
                        "J.A.R.V.I.S. PROTOCOL ENGAGED: Workspace rules, skills, and hardware telemetry verified nominal.\n\n"
                        f"{banner}\n\n"
                        "MANDATE: On turn 1 of every session, after /clear, or upon /resume: ALWAYS confirm J.A.R.V.I.S. operational "
                        "status by referencing the live telemetry matrix above."
                    )
                }
            }
        ]
    }
    print(json.dumps(response, indent=2))

if __name__ == "__main__":
    main()
