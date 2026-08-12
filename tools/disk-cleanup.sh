#!/usr/bin/env bash
#
# disk-cleanup.sh — reclaim disk space on Linux dev machines
#
# Usage:
#   ./disk-cleanup.sh              # interactive (prompt for each category)
#   ./disk-cleanup.sh --yes         # auto-confirm all categories
#   ./disk-cleanup.sh --dry-run     # show what would be cleaned, do nothing
#   ./disk-cleanup.sh --only docker,npm,uv   # run specific categories only
#
set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────
info()  { printf "\033[0;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[0;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[0;33m[warn]\033[0m  %s\n" "$1"; }
fail()  { printf "\033[0;31m[fail]\033[0m  %s\n" "$1"; exit 1; }
dim()   { printf "\033[0;2m  %s\033[0m\n" "$1"; }

# ── Options ────────────────────────────────────────────────────
AUTO_YES=false
DRY_RUN=false
ONLY=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --yes|-y)        AUTO_YES=true ;;
        --dry-run|-n)    DRY_RUN=true ;;
        --only)         shift; ONLY="$1" ;;
        *)  fail "Unknown option: $1. Usage: $0 [--yes|--dry-run|--only docker,npm,uv]" ;;
    esac
    shift
done

# ── Helpers ────────────────────────────────────────────────────
human_size() {
    # Convert bytes to human-readable (KB/MB/GB)
    local bytes="$1"
    if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.1fG\", $bytes/1073741824}"
    elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.1fM\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
        awk "BEGIN {printf \"%.1fK\", $bytes/1024}"
    else
        printf "%sB" "$bytes"
    fi
}

dir_size_bytes() {
    [ -e "$1" ] || { echo 0; return; }
    du -sb "$1" 2>/dev/null | awk '{print $1}'
}

disk_usage_percent() {
    df -P / | awk 'NR==2 {gsub(/%/,""); print $5}'
}

should_run() {
    # Check if this category is in --only filter
    if [ -n "$ONLY" ]; then
        echo ",$ONLY," | grep -q ",$1," || return 1
    fi
    # Prompt user unless auto-yes
    if $AUTO_YES; then
        return 0
    fi
    echo ""
    local prompt="  Clean $1? [y/N] "
    read -rp "$prompt" answer 2>/dev/null || answer="n"
    [ "$answer" = "y" ] || [ "$answer" = "Y" ]
}

run_or_echo() {
    if $DRY_RUN; then
        dim "  [dry-run] $*"
    else
        eval "$@"
    fi
}

# ── Before snapshot ─────────────────────────────────────────────
BEFORE_PCT=$(disk_usage_percent)
BEFORE_AVAIL=$(df -P / | awk 'NR==2 {print $4}')

echo ""
echo "============================================"
echo "  Disk Cleanup"
echo "============================================"
echo ""
info "Current disk usage: ${BEFORE_PCT}%  (avail: $(human_size "$BEFORE_AVAIL"))"

if $DRY_RUN; then
    warn "DRY RUN — no changes will be made"
fi

TOTAL_RECLAIMED=0

# ── Cleanup categories ─────────────────────────────────────────
# Each function:
#   1. Checks if the target exists / tool is installed
#   2. Measures current size
#   3. Cleans (or echoes in dry-run)
#   4. Reports reclaimed space

cleanup_docker() {
    command -v docker &>/dev/null || { dim "  docker not found, skipping"; return; }

    local before
    before=$(dir_size_bytes /var/lib/docker)
    [ "$before" -eq 0 ] && { dim "  /var/lib/docker not found, skipping"; return; }

    info "Docker: $(human_size "$before") in /var/lib/docker"

    if should_run "docker"; then
        run_or_echo "docker system prune -a --volumes -f"
        run_or_echo "docker builder prune -a -f"
        local after
        after=$(dir_size_bytes /var/lib/docker)
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "Docker: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_containerd() {
    [ -d /var/lib/containerd ] || { dim "  /var/lib/containerd not found, skipping"; return; }

    local before
    before=$(dir_size_bytes /var/lib/containerd)

    info "containerd: $(human_size "$before") in /var/lib/containerd"

    if should_run "containerd"; then
        if command -v ctr &>/dev/null; then
            # ctr content prune doesn't accept --all; prune references instead
            run_or_echo "ctr -n moby content prune references -f 2>/dev/null || true"
            run_or_echo "ctr -n k8s.io content prune references -f 2>/dev/null || true"
        fi
        # Remove empty snapshot directories (already-unlocked layers)
        run_or_echo "find /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots -maxdepth 1 -type d -empty -delete 2>/dev/null || true"
        local after
        after=$(dir_size_bytes /var/lib/containerd)
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "containerd: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_npm() {
    [ -d "$HOME/.npm" ] || { dim "  ~/.npm not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.npm")

    info "npm cache: $(human_size "$before") in ~/.npm"

    if should_run "npm"; then
        if command -v npm &>/dev/null; then
            run_or_echo "npm cache clean --force 2>/dev/null || true"
        fi
        # npx cache is separate and safe to delete
        run_or_echo "rm -rf \$HOME/.npm/_npx 2>/dev/null || true"
        run_or_echo "rm -rf \$HOME/.npm/_libvips 2>/dev/null || true"
        local after
        after=$(dir_size_bytes "$HOME/.npm")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "npm: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_uv() {
    [ -d "$HOME/.cache/uv" ] || { dim "  ~/.cache/uv not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.cache/uv")

    info "uv cache: $(human_size "$before") in ~/.cache/uv"

    if should_run "uv"; then
        if command -v uv &>/dev/null; then
            run_or_echo "uv cache clean 2>/dev/null || true"
        else
            run_or_echo "rm -rf \$HOME/.cache/uv 2>/dev/null || true"
        fi
        local after
        after=$(dir_size_bytes "$HOME/.cache/uv")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "uv: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_pip() {
    [ -d "$HOME/.cache/pip" ] || { dim "  ~/.cache/pip not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.cache/pip")

    info "pip cache: $(human_size "$before") in ~/.cache/pip"

    if should_run "pip"; then
        if command -v pip &>/dev/null; then
            run_or_echo "pip cache purge 2>/dev/null || true"
        else
            run_or_echo "rm -rf \$HOME/.cache/pip 2>/dev/null || true"
        fi
        local after
        after=$(dir_size_bytes "$HOME/.cache/pip")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "pip: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_pnpm() {
    [ -d "$HOME/.cache/pnpm" ] || { dim "  ~/.cache/pnpm not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.cache/pnpm")

    info "pnpm store: $(human_size "$before") in ~/.cache/pnpm"

    if should_run "pnpm"; then
        if command -v pnpm &>/dev/null; then
            run_or_echo "pnpm store prune 2>/dev/null || true"
        else
            run_or_echo "rm -rf \$HOME/.cache/pnpm 2>/dev/null || true"
        fi
        local after
        after=$(dir_size_bytes "$HOME/.cache/pnpm")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "pnpm: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_opencode_cache() {
    [ -d "$HOME/.cache/opencode" ] || { dim "  ~/.cache/opencode not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.cache/opencode")

    info "opencode cache: $(human_size "$before") in ~/.cache/opencode"

    if should_run "opencode-cache"; then
        run_or_echo "rm -rf \$HOME/.cache/opencode 2>/dev/null || true"
        local after
        after=$(dir_size_bytes "$HOME/.cache/opencode")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "opencode cache: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_selenium() {
    [ -d "$HOME/.cache/selenium" ] || { dim "  ~/.cache/selenium not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.cache/selenium")

    info "selenium cache: $(human_size "$before") in ~/.cache/selenium"

    if should_run "selenium"; then
        run_or_echo "rm -rf \$HOME/.cache/selenium 2>/dev/null || true"
        local after
        after=$(dir_size_bytes "$HOME/.cache/selenium")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "selenium: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_playwright_cache() {
    [ -d "$HOME/.cache/ms-playwright-mcp" ] || { dim "  ~/.cache/ms-playwright-mcp not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.cache/ms-playwright-mcp")

    info "playwright-mcp cache: $(human_size "$before") in ~/.cache/ms-playwright-mcp"

    if should_run "playwright-cache"; then
        run_or_echo "rm -rf \$HOME/.cache/ms-playwright-mcp 2>/dev/null || true"
        local after
        after=$(dir_size_bytes "$HOME/.cache/ms-playwright-mcp")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "playwright-mcp: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_vscode_server() {
    [ -d "$HOME/.vscode-server/cli" ] || { dim "  ~/.vscode-server/cli not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.vscode-server/cli")

    info "vscode-server: $(human_size "$before") in ~/.vscode-server/cli (old versions)"

    if should_run "vscode-server"; then
        # Keep only the latest CLI version, remove older ones
        # Each version is a subdirectory like: cli-0.123.456-abc123/
        local latest
        latest=$(ls -1t "$HOME/.vscode-server/cli/" 2>/dev/null | head -1)
        if [ -n "$latest" ]; then
            for dir in "$HOME/.vscode-server/cli/"*/; do
                local dirname
                dirname=$(basename "$dir")
                [ "$dirname" = "$latest" ] && continue
                run_or_echo "rm -rf \"\$HOME/.vscode-server/cli/$dirname\" 2>/dev/null || true"
            done
        fi
        local after
        after=$(dir_size_bytes "$HOME/.vscode-server/cli")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "vscode-server: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_apt_cache() {
    command -v apt &>/dev/null || { dim "  apt not found, skipping"; return; }

    local before
    before=$(dir_size_bytes /var/cache/apt)

    info "apt cache: $(human_size "$before") in /var/cache/apt"

    if should_run "apt-cache"; then
        run_or_echo "apt-get clean 2>/dev/null || true"
        run_or_echo "apt-get autoremove -y 2>/dev/null || true"
        local after
        after=$(dir_size_bytes /var/cache/apt)
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "apt: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_gem_cache() {
    [ -d "$HOME/.cache/gem" ] || { dim "  ~/.cache/gem not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.cache/gem")

    info "gem cache: $(human_size "$before") in ~/.cache/gem"

    if should_run "gem"; then
        if command -v gem &>/dev/null; then
            run_or_echo "gem cleanup 2>/dev/null || true"
        fi
        run_or_echo "rm -rf \$HOME/.cache/gem 2>/dev/null || true"
        local after
        after=$(dir_size_bytes "$HOME/.cache/gem")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "gem: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_node_cache() {
    [ -d "$HOME/.cache/node" ] || { dim "  ~/.cache/node not found, skipping"; return; }

    local before
    before=$(dir_size_bytes "$HOME/.cache/node")

    info "node cache: $(human_size "$before") in ~/.cache/node"

    if should_run "node-cache"; then
        run_or_echo "rm -rf \$HOME/.cache/node 2>/dev/null || true"
        local after
        after=$(dir_size_bytes "$HOME/.cache/node")
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "node cache: reclaimed $(human_size "$reclaimed")"
    fi
}

cleanup_tmp() {
    [ -d /tmp ] || return

    local before
    before=$(dir_size_bytes /tmp)

    info "tmp: $(human_size "$before") in /tmp (files older than 7 days)"

    if should_run "tmp"; then
        run_or_echo "find /tmp -maxdepth 1 -mindepth 1 -atime +7 -not -name '.*' -exec rm -rf {} + 2>/dev/null || true"
        local after
        after=$(dir_size_bytes /tmp)
        local reclaimed=$((before - after))
        TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + reclaimed))
        $DRY_RUN || ok "tmp: reclaimed $(human_size "$reclaimed")"
    fi
}

# ── Run all categories ─────────────────────────────────────────
echo ""
echo "Scanning cleanup targets..."
echo ""

cleanup_docker
cleanup_containerd
cleanup_npm
cleanup_uv
cleanup_pip
cleanup_pnpm
cleanup_opencode_cache
cleanup_selenium
cleanup_playwright_cache
cleanup_vscode_server
cleanup_apt_cache
cleanup_gem_cache
cleanup_node_cache
cleanup_tmp

# ── After snapshot ─────────────────────────────────────────────
echo ""
echo "============================================"
if $DRY_RUN; then
    warn "Dry run complete — no changes made"
    dim "  Would have reclaimed ~$(human_size "$TOTAL_RECLAIMED")"
else
    AFTER_PCT=$(disk_usage_percent)
    AFTER_AVAIL=$(df -P / | awk 'NR==2 {print $4}')
    ACTUAL_RECLAIMED=$((BEFORE_AVAIL - 0))
    ACTUAL_FREED=$((AFTER_AVAIL - BEFORE_AVAIL))

    ok "Cleanup complete!"
    echo ""
    printf "  Before:  %s%% used  (%s avail)\n" "$BEFORE_PCT" "$(human_size "$BEFORE_AVAIL")"
    printf "  After:   %s%% used  (%s avail)\n" "$AFTER_PCT" "$(human_size "$AFTER_AVAIL")"
    printf "  Freed:   %s\n" "$(human_size "$ACTUAL_FREED")"
fi
echo "============================================"
echo ""