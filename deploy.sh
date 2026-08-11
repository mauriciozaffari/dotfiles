#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="$HOME/.dotfiles"
BACKUP_BASE="$STATE_DIR/backups"
BACKUP_DIR="$BACKUP_BASE/$(date +%Y%m%d_%H%M%S)"
MANIFEST=""  # tracks backed-up files for rollback

HOOKS_DIR="$DOTFILES/git/hooks"
HOOKS_INSTALLED_FILE="$STATE_DIR/hooks_installed"  # projects that opted in
HOOKS_SKIPPED_FILE="$STATE_DIR/hooks_skipped"      # projects that opted out forever

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

    local real_src real_dst
    real_src="$(realpath "$src" 2>/dev/null || echo "$src")"
    real_dst="$(realpath "$dst" 2>/dev/null || echo "")"

    if [ "$real_src" = "$real_dst" ]; then
        ok "$dst (already linked)"
        return
    fi

    if [ -L "$dst" ]; then
        backup_file "$dst"
        rm -rf "$dst"
    elif [ -e "$dst" ]; then
        backup_file "$dst"
        rm -rf "$dst"
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

restore_vscodium_view_state() {
    local state_file="$DOTFILES/config/vscodium/view-state.json"
    local database="$HOME/.config/VSCodium/User/globalStorage/state.vscdb"

    [ -f "$state_file" ] || return

    if pgrep -f '^/usr/share/codium/codium$' >/dev/null 2>&1; then
        warn "VSCodium is running; skipping view-state restore. Close it and run deploy.sh again."
        return
    fi

    mkdir -p "$(dirname "$database")"
    python3 - "$state_file" "$database" <<'PY'
import json
import sqlite3
import sys

state_path, database_path = sys.argv[1:]
with open(state_path, encoding="utf-8") as state_file:
    state = json.load(state_file)

if state.get("version") != 1 or not isinstance(state.get("entries"), dict):
    raise SystemExit(f"Unsupported VSCodium view-state format: {state_path}")

database = sqlite3.connect(database_path)
with database:
    database.execute(
        "CREATE TABLE IF NOT EXISTS ItemTable "
        "(key TEXT UNIQUE ON CONFLICT REPLACE, value BLOB)"
    )
    database.executemany(
        "INSERT INTO ItemTable(key, value) VALUES (?, ?) "
        "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        state["entries"].items(),
    )
database.close()
PY
    ok "VSCodium view organization restored"
}

install_vscodium_extensions() {
    local extensions_file="$DOTFILES/config/vscodium/extensions.txt"

    [ -f "$extensions_file" ] || return
    if ! command -v codium >/dev/null 2>&1; then
        warn "VSCodium is not installed; skipping extensions"
        return
    fi

    local installed
    installed="$(codium --list-extensions)"
    while IFS= read -r extension; do
        [ -n "$extension" ] || continue
        if printf '%s\n' "$installed" | grep -qFx "$extension"; then
            continue
        fi
        info "Installing VSCodium extension: $extension"
        codium --install-extension "$extension"
    done < "$extensions_file"
    ok "VSCodium extensions installed"
}

# ──────────────────────────────────────────────────
# Git hooks helpers
# ──────────────────────────────────────────────────
is_in_file() {
    local needle="$1" file="$2"
    [ -f "$file" ] && grep -qFx "$needle" "$file" 2>/dev/null
}

add_to_file() {
    local line="$1" file="$2"
    is_in_file "$line" "$file" && return
    echo "$line" >> "$file"
}

remove_from_file() {
    local line="$1" file="$2"
    [ -f "$file" ] || return 0
    local tmp
    tmp="$(mktemp)"
    grep -vFx "$line" "$file" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$file"
}

install_hooks_to_project() {
    # Resolve actual git dir (submodules have a .git file, not a directory)
    local git_dir
    git_dir="$(git -C "$1" rev-parse --git-dir 2>/dev/null)" || return 1

    # Make absolute if relative
    case "$git_dir" in
        /*) ;;
        *)  git_dir="$1/$git_dir" ;;
    esac

    local project_hooks="$git_dir/hooks"

    for hook in "$HOOKS_DIR"/*; do
        [ -f "$hook" ] || continue
        local name
        name="$(basename "$hook")"
        local dst="$project_hooks/$name"

        if [ -L "$dst" ]; then
            local current
            current="$(readlink "$dst")"
            if [ "$current" = "$hook" ]; then
                continue  # already linked, silent
            fi
            backup_file "$dst"
            rm "$dst"
        elif [ -e "$dst" ]; then
            backup_file "$dst"
            rm "$dst"
        fi

        ln -s "$hook" "$dst"
    done
}

deploy_hooks() {
    local hook_files=()
    for f in "$HOOKS_DIR"/*; do
        [ -f "$f" ] && hook_files+=("$(basename "$f")")
    done

    if [ ${#hook_files[@]} -eq 0 ]; then
        return
    fi

    echo ""
    info "Git hooks: ${hook_files[*]}"
    echo ""

    # Ensure state files exist
    touch "$HOOKS_INSTALLED_FILE" "$HOOKS_SKIPPED_FILE"

    # 1. Update hooks in already-installed projects
    local updated=0
    while IFS= read -r project; do
        [ -z "$project" ] && continue
        if [ -d "$project" ] && git -C "$project" rev-parse --git-dir &>/dev/null; then
            install_hooks_to_project "$project"
            updated=$((updated + 1))
        else
            warn "$project is no longer a git repo, removing from installed list"
            remove_from_file "$project" "$HOOKS_INSTALLED_FILE"
        fi
    done < "$HOOKS_INSTALLED_FILE"

    if [ "$updated" -gt 0 ]; then
        ok "Updated hooks in $updated installed project(s)"
    fi

    install_hooks_to_project "$DOTFILES"

    # Discover new projects in ~/development
    local dev_dir="$HOME/development"
    if [ ! -d "$dev_dir" ]; then
        return
    fi

    # Find all git repos (including submodules which have .git as a file)
    local new_projects=()
    while IFS= read -r gitdir; do
        local project
        project="$(dirname "$gitdir")"

        # Skip if already installed or permanently skipped
        is_in_file "$project" "$HOOKS_INSTALLED_FILE" && continue
        is_in_file "$project" "$HOOKS_SKIPPED_FILE" && continue

        new_projects+=("$project")
    done < <(find "$dev_dir" -name ".git" -maxdepth 3 2>/dev/null | sort)

    if [ ${#new_projects[@]} -eq 0 ]; then
        return
    fi

    if [ "$NON_INTERACTIVE" = true ]; then
        info "Skipping hooks for ${#new_projects[@]} unconfigured project(s) in non-interactive mode"
        return
    fi

    echo ""
    info "Found ${#new_projects[@]} project(s) without hooks:"
    echo ""

    for project in "${new_projects[@]}"; do
        local rel="${project#$HOME/}"
        echo "  $rel"
    done

    echo ""
    echo "  i) Install hooks in all listed projects"
    echo "  s) Skip all for this run"
    echo "  p) Pick individually"
    echo ""
    read -rp "Choose [i/s/p]: " bulk_choice

    case "$bulk_choice" in
        i|I)
            for project in "${new_projects[@]}"; do
                install_hooks_to_project "$project"
                add_to_file "$project" "$HOOKS_INSTALLED_FILE"
                ok "Installed hooks in ${project#$HOME/}"
            done
            ;;
        p|P)
            for project in "${new_projects[@]}"; do
                local rel="${project#$HOME/}"
                echo ""
                echo "  $rel"
                echo "    y) Install    s) Skip this run    n) Never install"
                read -rp "  Choose [y/s/n]: " pick
                case "$pick" in
                    y|Y)
                        install_hooks_to_project "$project"
                        add_to_file "$project" "$HOOKS_INSTALLED_FILE"
                        ok "Installed hooks in $rel"
                        ;;
                    n|N)
                        add_to_file "$project" "$HOOKS_SKIPPED_FILE"
                        warn "Permanently skipped $rel"
                        ;;
                    *)
                        info "Skipped $rel for this run"
                        ;;
                esac
            done
            ;;
        *)
            info "Skipping hook installation for this run"
            ;;
    esac
}

# ──────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────
NON_INTERACTIVE=false
ROLLBACK=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --non-interactive|-n)
            NON_INTERACTIVE=true
            ;;
        --rollback)
            ROLLBACK=true
            ;;
    esac
    shift
done

if [ ! -t 0 ]; then
    NON_INTERACTIVE=true
fi

if [ "$ROLLBACK" = true ]; then
    do_rollback
fi

mkdir -p "$STATE_DIR"

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
link_file "$DOTFILES/config/tmux/tmux.conf" "$HOME/.tmux.conf"
echo ""

# OpenCode
info "OpenCode configuration"
link_file "$DOTFILES/config/opencode/AGENTS.md"      "$HOME/.config/opencode/AGENTS.md"
link_file "$DOTFILES/config/opencode/opencode.jsonc"  "$HOME/.config/opencode/opencode.jsonc"
link_file "$DOTFILES/config/opencode/oh-my-openagent.json" "$HOME/.config/opencode/oh-my-openagent.json"
for plugin in "$DOTFILES/config/opencode/plugin/"*.ts; do
    [ -e "$plugin" ] || continue
    link_file "$plugin" "$HOME/.config/opencode/plugin/$(basename "$plugin")"
done

for plugin in "$DOTFILES/config/opencode/plugins/"*.js; do
    [ -e "$plugin" ] || continue
    link_file "$plugin" "$HOME/.config/opencode/race-control/$(basename "$plugin")"
done

for agent in "$DOTFILES/config/opencode/agent/"*.md; do
    [ -e "$agent" ] || continue
    link_file "$agent" "$HOME/.config/opencode/agent/$(basename "$agent")"
done

for skill_dir in "$DOTFILES/config/opencode/skills/"*/; do
    [ -d "$skill_dir" ] || continue
    skill_dir="${skill_dir%/}"
    local_name="$(basename "$skill_dir")"
    link_file "$skill_dir" "$HOME/.config/opencode/skills/$local_name"
done
echo ""

# VSCodium
info "VSCodium configuration"
link_file "$DOTFILES/config/vscodium/product.json" "$HOME/.config/VSCodium/product.json"
link_file "$DOTFILES/config/vscodium/User/settings.json" "$HOME/.config/VSCodium/User/settings.json"
link_file "$DOTFILES/config/vscodium/User/keybindings.json" "$HOME/.config/VSCodium/User/keybindings.json"
link_file "$DOTFILES/config/vscodium/User/globalStorage/alefragnani.project-manager/projects.json" \
    "$HOME/.config/VSCodium/User/globalStorage/alefragnani.project-manager/projects.json"
restore_vscodium_view_state
install_vscodium_extensions
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

# Git hooks
deploy_hooks

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
