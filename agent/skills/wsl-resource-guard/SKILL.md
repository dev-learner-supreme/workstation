---
name: wsl-resource-guard
description: Guidelines and commands to monitor and constrain memory, CPU, and disk usage within WSL2 on the Acer Swift Go 14 laptop.
---

# WSL2 Resource Guard

The host machine is an **Acer Swift Go 14 (SFG14-71)** running **WSL2 on Windows 11**.

Hardware thermals and fan management are handled entirely by Windows. The agent's boundary is strictly to manage the **WSL2 resource footprint** (RAM, vCPU concurrency, disk space) so that background tasks and builds never degrade the user experience on either WSL or Windows.

## Gradle & Android Build Constraints

When compiling or running tests in `ProjectAgri`, always restrict Gradle memory allocation and worker concurrency:

```bash
./gradlew <task> -Dorg.gradle.jvmargs="-Xmx1536m" -Pkotlin.compiler.execution.strategy=in-process --max-workers=2
```

## Node.js & Next.js Builds

When running Next.js builds (CMS or RODO-Website):
- Avoid running multiple builds in parallel across repositories.
- If memory is tight, limit V8 heap size:
  ```bash
  NODE_OPTIONS="--max-old-space-size=2048" npm run build
  ```

## Disk & Workspace Hygiene

- **Physical SSD Headroom:** Physical drive is a 512 GB NVMe SSD (~476 GB formatted, ~413 GB available on Windows C:).
  - *Caution on WSL Inaccuracy:* Linux `df -h /` measures the virtual sparse VHDX ceiling (~1 TB), completely ignoring real Windows SSD limits. Always monitor real physical capacity via `/mnt/c`.
- Never place uncommitted files or long-term secrets in `/tmp` because `/tmp` is a `tmpfs` in WSL2 that gets wiped on every restart.
- Periodically clear unneeded build caches:
  ```bash
  rm -rf /home/arun/Work/*/.next /home/arun/Work/*/build /home/arun/Work/*/.gradle
  ```
