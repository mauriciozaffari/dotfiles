#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP_BASE="$HOME/.dotfiles_backup"
BACKUP_DIR="$BACKUP_BASE/$(date +%Y%m%d_%H%M%S)"
MANIFEST=""  # tracks backed-up files for rollback

info()  { printf "\033[0;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[0;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[0;33m[warn]\033[0m  %s\n" "$1"; }
fail()  { printf "\033[0;31m[fail]\033[0m  %s\n" "$1"; exit 1; }

# ──────────────────────────────────────────────────
# Rollback
# ──────────────────────────────────────────────────
do_rollback() {
    echo ""
    echo "Available backups:"
    echo "================================="

    local backups=()
    for dir in "$BACKUP_BASE"/*/; do
        [ -d "$dir" ] || continue
        [ -f "$dir/manifest" ] || continue
        backups+=("$dir")
    done

    if [ ${#backups[@]} -eq 0 ]; then
        warn "No backups with manifests found in $BACKUP_BASE"
        exit 0
    fi

    local i=1
    for dir in "${backups[@]}"; do
        local ts
        ts="$(basename "$dir")"
        local count
        count="$(wc -l < "$dir/manifest")"
        printf "  %d) %s (%d files)\n" "$i" "$ts" "$count"
        i=$((i + 1))
    done

    echo ""
    read -rp "Select backup to restore [1-${#backups[@]}]: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#backups[@]} ]; then
        fail "Invalid selection"
    fi

    local selected="${backups[$((choice - 1))]}"
    info "Restoring from $(basename "$selected")..."

    while IFS=$'\t' read -r backup_path original_path; do
        if [ ! -e "$backup_path" ]; then
            warn "Backup file missing: $backup_path, skipping"
            continue
        fi

        # Remove the symlink (or whatever is there now)
        if [ -e "$original_path" ] || [ -L "$original_path" ]; then
            rm "$original_path"
        fi

        mv "$backup_path" "$original_path"
        ok "Restored $original_path"
    done < "$selected/manifest"

    # Clean up empty backup directory
    rm "$selected/manifest"
    find "$selected" -type d -empty -delete 2>/dev/null || true
    ok "Rollback complete"
    exit 0
}

# ──────────────────────────────────────────────────
# Deploy helpers
# ──────────────────────────────────────────────────
backup_file() {
    local dst="$1"
    local rel_path="${dst#$HOME/}"
    local backup_path="$BACKUP_DIR/$rel_path"

    mkdir -p "$(dirname "$backup_path")"
    cp -a "$dst" "$backup_path"
    MANIFEST+="$backup_path\t$dst\n"
}

link_file() {
    local src="$1" dst="$2"

    if [ -L "$dst" ]; then
        local current
        current="$(readlink "$dst")"
        if [ "$current" = "$src" ]; then
            ok "$dst (already linked)"
            return
        fi
        backup_file "$dst"
        rm "$dst"
    elif [ -e "$dst" ]; then
        backup_file "$dst"
        rm "$dst"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    ok "$dst -> $src"
}

save_manifest() {
    if [ -n "$MANIFEST" ]; then
        mkdir -p "$BACKUP_DIR"
        printf "%b" "$MANIFEST" > "$BACKUP_DIR/manifest"
    fi
}

# ──────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────
if [ "${1:-}" = "--rollback" ]; then
    do_rollback
fi

echo ""
echo "Deploying dotfiles from $DOTFILES"
echo "================================="
echo ""

# Shell
info "Shell configuration"
link_file "$DOTFILES/shell/zshrc"          "$HOME/.zshrc"
link_file "$DOTFILES/shell/docker_helpers" "$HOME/.docker_helpers"
echo ""

# Git
info "Git configuration"
link_file "$DOTFILES/git/gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES/git/gitignore" "$HOME/.gitignore"
echo ""

# Tools
info "Tool configuration"
link_file "$DOTFILES/tools/asdfrc"        "$HOME/.asdfrc"
link_file "$DOTFILES/tools/tool-versions" "$HOME/.tool-versions"
link_file "$DOTFILES/tools/gemrc"         "$HOME/.gemrc"
echo ""

# SSH
info "SSH configuration"
link_file "$DOTFILES/ssh/config" "$HOME/.ssh/config"
echo ""

# XDG Config
info "XDG config files"
link_file "$DOTFILES/config/git/ignore"   "$HOME/.config/git/ignore"
link_file "$DOTFILES/config/htop/htoprc"  "$HOME/.config/htop/htoprc"
echo ""

# OpenCode
info "OpenCode configuration"
link_file "$DOTFILES/config/opencode/AGENTS.md"      "$HOME/.config/opencode/AGENTS.md"
link_file "$DOTFILES/config/opencode/opencode.jsonc"  "$HOME/.config/opencode/opencode.jsonc"
link_file "$DOTFILES/config/opencode/plugin/block-hardcoded-secrets.ts" \
          "$HOME/.config/opencode/plugin/block-hardcoded-secrets.ts"

for agent in "$DOTFILES/config/opencode/agent/"*.md; do
    [ -e "$agent" ] || continue
    link_file "$agent" "$HOME/.config/opencode/agent/$(basename "$agent")"
done

for skill_dir in "$DOTFILES/config/opencode/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    local_name="$(basename "$skill_dir")"
    for file in "$skill_dir"*; do
        [ -e "$file" ] || continue
        link_file "$file" "$HOME/.config/opencode/skills/$local_name/$(basename "$file")"
    done
done
echo ""

# AGENTS.md
info "AI assistant configuration"
link_file "$DOTFILES/AGENTS.md" "$HOME/AGENTS.md"
link_file "$HOME/AGENTS.md"     "$HOME/CLAUDE.md"
link_file "$HOME/AGENTS.md"     "$HOME/GEMINI.md"
echo ""

# Secrets
if [ ! -f "$HOME/.secrets" ]; then
    warn "~/.secrets does not exist. Creating from example..."
    cp "$DOTFILES/secrets.example" "$HOME/.secrets"
    chmod 600 "$HOME/.secrets"
    info "Edit ~/.secrets to add your API keys and tokens"
fi

# Save manifest for rollback
save_manifest

echo ""
echo "================================="
ok "Deployment complete!"
if [ -n "$MANIFEST" ]; then
    info "Backup saved to $BACKUP_DIR"
    info "To rollback: ~/dotfiles/deploy.sh --rollback"
fi
echo ""
