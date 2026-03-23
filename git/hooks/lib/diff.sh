#!/usr/bin/env bash
# Build staged diff for AI prompt

MAX_FILE_DIFF=2000   # Max chars per file diff
MAX_TOTAL_DIFF=8000  # Max total diff size

build_staged_diff() {
    local staged_files diff="" excluded_files=""

    staged_files="$(git diff --cached --name-only)"
    [ -z "$staged_files" ] && return 1

    while IFS= read -r file; do
        local file_diff file_size
        file_diff="$(git diff --cached --no-color -- "$file")"
        file_size="${#file_diff}"

        if [ "$file_size" -gt "$MAX_FILE_DIFF" ]; then
            excluded_files="${excluded_files}${file} (${file_size} chars)"$'\n'
        else
            diff="${diff}${file_diff}"$'\n'
        fi
    done <<< "$staged_files"

    # Fallback to stat summary when all diffs are too large
    if [ -z "$diff" ]; then
        diff="$(git diff --cached --stat)"
    fi

    # Truncate if still too large
    if [ "${#diff}" -gt "$MAX_TOTAL_DIFF" ]; then
        diff="${diff:0:$MAX_TOTAL_DIFF}

... (diff truncated, ${#diff} chars total)"
    fi

    echo "$diff"

    # Return excluded context via global variable
    DIFF_EXCLUDED=""
    if [ -n "$excluded_files" ]; then
        DIFF_EXCLUDED="
Also staged (large diff excluded):
${excluded_files}"
    fi
}
