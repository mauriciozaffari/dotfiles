---
name: disk-cleanup
description: Reclaim disk space on Linux dev machines. Use when the user says "disk cleanup", "free up space", "disk is full", "clean up disk", "reclaim space", "storage full", "disk usage too high", or asks what's filling up the disk. Also triggers on df/du investigations that reveal low disk space.
---

# Disk Cleanup

You are a disk cleanup specialist for Linux development machines. Your job is to find what's consuming disk space and reclaim what's safe to clean.

## Workflow

### 1. Assess Current Disk Usage

Run these to get the lay of the land:

```bash
df -h /                          # Overall disk usage
du -h --max-depth=1 / 2>/dev/null | sort -rh | head -20   # Top-level breakdown
```

If the root-level `du` is too slow (timeout), drill into the usual suspects in parallel:

```bash
du -h --max-depth=1 /var 2>/dev/null | sort -rh | head -10
du -h --max-depth=1 /root 2>/dev/null | sort -rh | head -10
du -h --max-depth=1 /usr 2>/dev/null | sort -rh | head -10
du -h --max-depth=1 /home 2>/dev/null | sort -rh | head -10
du -h --max-depth=1 /tmp /opt /srv 2>/dev/null | sort -rh | head -10
```

Continue drilling into the largest directories until you have a clear picture of the top 5-10 space consumers.

### 2. Identify Cleanup Targets

Common Linux dev machine space hogs:

| Target | Location | Safe to Clean? |
|--------|----------|----------------|
| Docker images/containers/volumes | `/var/lib/docker` | Yes — `docker system prune -a --volumes` |
| containerd snapshots/content | `/var/lib/containerd` | Yes — prune unused content |
| npm cache + npx | `~/.npm` | Yes — `npm cache clean --force`, `rm -rf ~/.npm/_npx` |
| uv (Python) cache | `~/.cache/uv` | Yes — `uv cache clean` |
| pip cache | `~/.cache/pip` | Yes — `pip cache purge` |
| pnpm store | `~/.cache/pnpm` | Yes — `pnpm store prune` |
| opencode cache | `~/.cache/opencode` | Yes — safe to `rm -rf` |
| selenium drivers | `~/.cache/selenium` | Yes — will re-download when needed |
| playwright-mcp cache | `~/.cache/ms-playwright-mcp` | Yes — safe to `rm -rf` |
| VS Code Server old CLI versions | `~/.vscode-server/cli/*` | Yes — keep only latest |
| apt cache | `/var/cache/apt` | Yes — `apt-get clean`, `apt-get autoremove` |
| gem cache | `~/.cache/gem` | Yes — `gem cleanup` or `rm -rf` |
| node cache | `~/.cache/node` | Yes — safe to `rm -rf` |
| old /tmp files | `/tmp` | Partial — files older than 7 days |

**NEVER clean** without user confirmation:
- `~/.local/share` (application data, may be important)
- `~/.config` (configuration files)
- `~/.asdf` (runtime versions — in use)
- `/usr/local/lib` (system packages)
- `~/development` (user's projects)
- Anything you're not sure about — ask the user

### 3. Present Findings to User

Before cleaning, present a summary table:

```
| Location | Size | What it is | Reclaimable? |
|---|---|---|---|
| /var/lib/containerd | 9.0G | Container images | ~2G |
| ~/.cache/uv | 1.6G | Python package cache | Yes (all) |
```

Include total easily reclaimable estimate.

### 4. Run Cleanup Script

The dotfiles repo includes a cleanup script at `~/dotfiles/tools/disk-cleanup.sh`.

**Options:**
```bash
# Interactive (prompts for each category)
~/dotfiles/tools/disk-cleanup.sh

# Auto-confirm all categories
~/dotfiles/tools/disk-cleanup.sh --yes

# Dry run (show what would be cleaned, change nothing)
~/dotfiles/tools/disk-cleanup.sh --dry-run

# Run specific categories only
~/dotfiles/tools/disk-cleanup.sh --only docker,npm,uv
```

The script handles these cleanup categories:
- docker (images, containers, volumes, build cache)
- containerd (unused content + empty snapshots)
- npm (cache + npx + libvips)
- uv (Python package cache)
- pip (pip cache)
- pnpm (pnpm store)
- opencode-cache (opencode cache directory)
- selenium (selenium driver cache)
- playwright-cache (playwright-mcp cache)
- vscode-server (old CLI version binaries)
- apt-cache (apt clean + autoremove)
- gem (gem cache)
- node-cache (node cache directory)
- tmp (files older than 7 days)

### 5. Verify Results

After cleanup, re-check disk usage:

```bash
df -h /
```

Compare before/after and report how much was reclaimed.

### 6. Manual Cleanup (if script doesn't cover it)

If the user has unusual space consumers not covered by the script:

1. Identify the specific directory/files consuming space
2. Check if it's safe to delete (research if unsure)
3. Present the finding and ask for confirmation
4. Clean manually with `rm -rf` or appropriate tool
5. Verify the space was reclaimed

## Guidelines

- **Always show before/after** — the user needs to see the impact
- **Dry run first** if the user is cautious — `--dry-run` shows what would be cleaned
- **Never delete user data** — when in doubt, ask
- **Use `--yes` for autonomous cleanup** — when the user just says "clean it all"
- **Report in human-readable sizes** — GB/MB, not raw bytes
- **Be thorough** — drill down until you find the real space hogs, don't stop at the first level