#!/usr/bin/env bash
# Sanitize AI-generated commit message output

sanitize_ai_output() {
    printf '%s\n' "$1" | awk '
    {
        sub(/\r$/, "", $0)
    }
    /^[[:space:]]*```/ { next }
    {
        lines[++count] = $0
    }
    END {
        start = 1
        while (start <= count && lines[start] ~ /^[[:space:]]*$/) {
            start++
        }

        finish = count
        while (finish >= start && lines[finish] ~ /^[[:space:]]*$/) {
            finish--
        }

        for (i = start; i <= finish; i++) {
            print lines[i]
        }
    }
    '
}
