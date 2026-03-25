#!/usr/bin/env bash

pre_commit_red=$'\033[0;31m'
pre_commit_green=$'\033[0;32m'
pre_commit_yellow=$'\033[1;33m'
pre_commit_nc=$'\033[0m'

pre_commit_print_bypass_help() {
    echo ""
    echo "To bypass this check (not recommended):"
    echo "  git commit --no-verify"
}

pre_commit_fail() {
    local title="$1"
    local output="$2"
    local hint="$3"

    echo "${pre_commit_red}Cannot commit: $title${pre_commit_nc}"

    if [ -n "$output" ]; then
        echo ""
        echo "$output"
    fi

    if [ -n "$hint" ]; then
        echo ""
        echo "$hint"
    fi

    pre_commit_print_bypass_help
    return 1
}

pre_commit_repo_root() {
    git rev-parse --show-toplevel 2>/dev/null
}

pre_commit_git_dir() {
    git rev-parse --git-dir 2>/dev/null
}
