#!/usr/bin/env bash
# Extract ticket number from branch name

extract_ticket() {
    local branch
    branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

    # Skip release branches
    [[ "$branch" == release-* ]] && return

    local ticket_raw
    ticket_raw="$(echo "$branch" | grep -Eo '(\w+[-])?[0-9]+' | tr '[:lower:]' '[:upper:]' | head -1)"

    if [ -n "$ticket_raw" ]; then
        echo "[$ticket_raw]"
    fi
}
