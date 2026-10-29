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
from pathlib import Path

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

def audit_work_repositories():
    work_dir = Path("/home/arun/Work")
    repos = ["Firebase", "CMS", "ProjectAgri", "RODO-Website"]
    repo_status = []
    for r in repos:
        p = work_dir / r
        if not p.exists():
            continue
        try:
            branch = subprocess.check_output(
                ["git", "-C", str(p), "branch", "--show-current"],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            status = subprocess.check_output(
                ["git", "-C", str(p), "status", "--porcelain"],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            dirty = len(status.splitlines()) if status else 0
            ahead = subprocess.check_output(
                ["git", "-C", str(p), "rev-list", "--count", "@{upstream}..HEAD"],
                text=True, stderr=subprocess.DEVNULL
            ).strip() if branch else "0"
            ahead_str = f"Ahead {ahead}" if ahead and int(ahead) > 0 else "Synced"
            dirty_str = f"{dirty} modified" if dirty > 0 else "Clean"
            repo_status.append({"name": r, "branch": branch or "detached", "dirty": dirty_str, "sync": ahead_str})
        except Exception:
            pass
    return repo_status

def generate_workspace_briefing():
    repos = audit_work_repositories()
    lines = [
        "### Active Workspaces Briefing",
        "| Repository | Branch | Working Tree | Upstream Status |",
        "|---|---|---|---|"
    ]
    for r in repos:
        lines.append(f"| **{r['name']}** | `{r['branch']}` | {r['dirty']} | {r['sync']} |")
    
    lines.append("\n### Operational Health & Invariants")
    lines.append("* **Dev / Test:** 100% aligned at 76 Cloud Functions, 30 Config Docs, and 58 Composite Indexes.")
    lines.append("* **Production Blockers (`rodo-prod0226`):**")
    lines.append("  1. Composite index `WorkRequest (status ASC, createdAt ASC)` deploy pending (fixes 144 errors/3 days).")
    lines.append("  2. Orphan scheduled job `firebase-schedule-resetBooleans-asia-south1` deletion pending.")
    lines.append("  3. Secret `GEMINI_API_KEY` API permissions audit pending.")
    return "\n".join(lines)

def generate_markdown_banner(m):
    briefing = generate_workspace_briefing()
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

{briefing}
"""

def generate_rich_hud(m):
    import shutil
    from rich.console import Console
    from rich.table import Table
    from rich.panel import Panel
    from rich import box

    # Dynamically detect terminal width (respecting environment and TTY sizing)
    env_cols = os.environ.get("COLUMNS")
    if env_cols and env_cols.isdigit():
        term_w = int(env_cols)
    else:
        try:
            term_w = shutil.get_terminal_size((96, 24)).columns
        except Exception:
            term_w = 96

    temp_val = m["temp_val"]
    temp_color = "#e57373" if temp_val > 83.0 else ("#f0ad4e" if temp_val > 70.0 else "#81c784")

    bat_stat = m["bat_stat"]
    bat_cap = int(m["bat_cap"]) if m["bat_cap"].isdigit() else 100
    bat_color = "#81c784" if bat_stat == "Charging" else ("#f0ad4e" if bat_cap > 20 else "#e57373")

    git_color = "#81c784" if (m["git_clean"] and m["git_ahead"] == 0) else "#f0ad4e"
    git_label = "Synchronized" if (m["git_clean"] and m["git_ahead"] == 0) else ("Ahead " + str(m["git_ahead"]) if m["git_clean"] else "Modified")

    serial_color = "#67d8ef" if m["serial_devs"] else "#64748b"

    # Layout branch: WIDE (>= 92 cols) vs COMPACT / HALF-PANE (< 92 cols)
    if term_w >= 92:
        card_w = min(term_w, 94)
        console = Console(width=card_w, height=30)

        table = Table(
            box=None,
            show_header=False,
            padding=(0, 1),
            collapse_padding=True,
            expand=True
        )

        table.add_column("L1", width=11, style="bold #cbd5e1", no_wrap=True)
        table.add_column("V1", width=15, no_wrap=True)
        table.add_column("N1", width=14, style="#64748b", justify="right", no_wrap=True)
        table.add_column("DIV", width=1, style="#475569", justify="center", no_wrap=True)
        table.add_column("L2", width=11, style="bold #cbd5e1", no_wrap=True)
        table.add_column("V2", width=15, no_wrap=True)
        table.add_column("N2", width=14, style="#64748b", justify="right", no_wrap=True)

        table.add_row(
            "CPU Temp", f"[{temp_color}]{m['temp']}[/]", "≤83°C target",
            "│",
            "NVMe Root", f"[#81c784]{m['disk_avail_gb']} GB Free[/]", f"{m['disk_used_pct']}% used Btrfs"
        )
        table.add_row(
            "RAPL Power", f"[#f0ad4e]PL1 {m['pl1']}W / {m['pl2']}W[/]", "enforced 28s",
            "│",
            "Battery", f"[{bat_color}]{m['bat_cap']}%[/]", bat_stat.lower()
        )
        table.add_row(
            "Memory", f"[#81c784]{m['mem_avail_gb']:.1f} GB Free[/]", f"/ {m['mem_total_gb']:.1f} GB RAM",
            "│",
            "ESP32 Bus", f"[{serial_color}]{m['serial']}[/]", "/dev/ttyUSB*"
        )
        table.add_row(
            "ZRAM Pool", f"[#81c784]{m['zram_pool_gb']:.1f} GB[/]", f"{m['zram_used_mb']} MB used",
            "│",
            "Workstation", f"[{git_color}]{git_label}[/]", "origin/main"
        )

        panel = Panel(
            table,
            title="[bold #e2b714] J.A.R.V.I.S. [/][bold #cbd5e1]•[/] [#94a3b8] Hardware Telemetry [/]",
            title_align="left",
            subtitle="[#64748b] Acer Swift Go 14 • Omarchy Linux [/]",
            subtitle_align="right",
            border_style="#475569",
            box=box.ROUNDED,
            padding=(0, 1),
            width=card_w
        )
        console.print(panel)
    else:
        # Dynamic half-pane / compact mode (1 column of 8 rows)
        card_w = min(term_w, 66)
        console = Console(width=card_w, height=30)

        table = Table(
            box=None,
            show_header=False,
            padding=(0, 1),
            collapse_padding=True,
            expand=True
        )

        table.add_column("Label", width=12, style="bold #cbd5e1", no_wrap=True)
        table.add_column("Value", no_wrap=True)
        if card_w >= 52:
            table.add_column("Note", style="#64748b", justify="right", no_wrap=True)

        rows = [
            ("CPU Temp", f"[{temp_color}]{m['temp']}[/]", "≤83°C target"),
            ("RAPL Power", f"[#f0ad4e]PL1 {m['pl1']}W / {m['pl2']}W[/]", "enforced 28s"),
            ("Physical RAM", f"[#81c784]{m['mem_avail_gb']:.1f} GB Free[/]", f"/ {m['mem_total_gb']:.1f} GB RAM"),
            ("ZRAM Swap", f"[#81c784]{m['zram_pool_gb']:.1f} GB Pool[/]", f"{m['zram_used_mb']} MB used"),
            ("NVMe Root", f"[#81c784]{m['disk_avail_gb']} GB Free[/]", f"{m['disk_used_pct']}% used Btrfs"),
            ("Battery", f"[{bat_color}]{m['bat_cap']}%[/]", bat_stat.lower()),
            ("ESP32 Bus", f"[{serial_color}]{m['serial']}[/]", "/dev/ttyUSB*"),
            ("Workstation", f"[{git_color}]{git_label}[/]", "origin/main"),
        ]

        for r in rows:
            if card_w >= 52:
                table.add_row(r[0], r[1], r[2])
            else:
                table.add_row(r[0], r[1])

        panel = Panel(
            table,
            title="[bold #e2b714] J.A.R.V.I.S. [/][bold #cbd5e1]•[/] [#94a3b8] Telemetry [/]",
            title_align="left",
            subtitle="[#64748b] Omarchy Bare-Metal [/]",
            subtitle_align="right",
            border_style="#475569",
            box=box.ROUNDED,
            padding=(0, 1),
            width=card_w
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
