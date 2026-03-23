#!/usr/bin/env bash
# Per-project configuration management
#
# Config file: .git/commit-ai.conf
# Format: one provider:model per line, in priority order

AVAILABLE_PROVIDERS=(opencode claude codex)

config_file() {
    local git_dir
    git_dir="$(git rev-parse --git-dir 2>/dev/null)" || return 1
    echo "$git_dir/commit-ai.conf"
}

config_exists() {
    local conf
    conf="$(config_file)" || return 1
    [ -f "$conf" ] && [ -s "$conf" ]
}

config_read() {
    local conf
    conf="$(config_file)" || return 1
    [ -f "$conf" ] && cat "$conf"
}

config_write() {
    local conf entries="$1"
    conf="$(config_file)" || return 1
    echo "$entries" > "$conf"
}

load_providers() {
    local lib_dir="$1"
    for provider in "${AVAILABLE_PROVIDERS[@]}"; do
        source "$lib_dir/providers/${provider}.sh"
    done
}
