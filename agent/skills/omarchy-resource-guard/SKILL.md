---
name: omarchy-resource-guard
description: Guidelines and commands to monitor and constrain memory, CPU thermals, and disk usage on the Acer Swift Go 14 running Omarchy Linux.
---

# Omarchy Resource Guard & Hardware Constraints

The host machine is an **Acer Swift Go 14 (SFG14-71)** running bare-metal **Omarchy 4 (Arch Linux + Hyprland)**.

## Hardware & Architecture Specs
* **Processor**: Intel Core i5-13500H (12 cores / 16 threads, 4P + 8E).
* **Memory**: 16 GB LPDDR5 with compressed `zram-generator` (zstd algorithm), yielding ~20–22 GB effective usable memory.
* **Storage**: 512 GB NVMe SSD (`/dev/mapper/root` on Btrfs with `compress=zstd:3` and async TRIM).
* **Thermal Envelope**: Managed by `/usr/local/sbin/cpu-power-cap` (PL1 18W / PL2 35W / tau 28s) to lock temperatures strictly under 83°C.

## 1. Gradle & Android Build Constraints
When compiling or running tests in `ProjectAgri`, constrain Gradle heap and worker count to prevent CPU thermal saturation:

```bash
./gradlew <task> -Dorg.gradle.jvmargs="-Xmx2048m" -Pkotlin.compiler.execution.strategy=in-process --max-workers=4
```

## 2. Node.js & Next.js Builds
When running Next.js builds (CMS or RODO-Website):
- Avoid running multiple concurrent production builds simultaneously.
- If running under constrained memory conditions:
  ```bash
  NODE_OPTIONS="--max-old-space-size=2048" npm run build
  ```

## 3. Thermal Capping & Power Monitoring
* Check active RAPL power limits and package temperature:
  ```bash
  /usr/local/sbin/cpu-power-stats
  tail -n 20 /var/log/cpu-power-stats.csv
  ```
* Enforce power-capping service status:
  ```bash
  systemctl status cpu-power-cap.service
  ```

## 4. Disk & Btrfs Hygiene
* **Root Filesystem Headroom:** Formatted as Btrfs on NVMe. Keep at least 15% free space to allow Btrfs copy-on-write balance and Snapper snapshots to operate without performance degradation.
* **Storage Wipe Caution:** Never leave durable project files or exclusive credentials in `/tmp`. Always keep files under version-controlled directories in `$HOME/`.
* Periodically prune build artifacts:
  ```bash
  rm -rf /home/arun/Work/*/.next /home/arun/Work/*/build /home/arun/Work/*/.gradle
  ```
