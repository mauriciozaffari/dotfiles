#!/usr/bin/env bash

prepare_commit_msg_main() {
    local file="$1"
    local commit_source="${2:-}"

    [[ -n "$commit_source" && "$commit_source" != "template" ]] && return 0
    [[ -n "$(head -n 1 "$file" | grep -v '^#' | grep -v '^$')" ]] && return 0

    source "$LIB_DIR/config.sh"
    source "$LIB_DIR/ticket.sh"
    source "$LIB_DIR/diff.sh"
    source "$LIB_DIR/prompt.sh"
    source "$LIB_DIR/sanitize.sh"
    source "$LIB_DIR/configure.sh"

    load_providers "$LIB_DIR"

    local ticket existing diff prompt result tmp_err provider_rc warn_line
    ticket="$(extract_ticket)"
    existing="$(cat "$file")"

    diff="$(build_staged_diff)"
    [ -z "$diff" ] && return 0

    if ! config_exists; then
        run_configure
        if ! config_exists; then
            [[ -n "$ticket" ]] && { echo "$ticket "; echo "$existing"; } > "$file"
            return 0
        fi
    fi

    prompt="$(build_prompt "$diff" "$DIFF_EXCLUDED")"
    result=""

    while IFS=: read -r provider model; do
        [ -z "$provider" ] || [ -z "$model" ] && continue

        if ! "provider_${provider}_installed" 2>/dev/null; then
            continue
        fi

        echo "Generating commit message with $(provider_${provider}_name) / $model..." >&2

        tmp_err="$(mktemp)"
        provider_rc=0
        if result="$("provider_${provider}_generate" "$model" "$prompt" 2>"$tmp_err")"; then
            result="$(sanitize_ai_output "$result")"
            if [ -z "$result" ]; then
                if [ -s "$tmp_err" ]; then
                    warn_line="$(grep -v '^$' "$tmp_err" | tail -1 | tr -d '\r')"
                    [ -n "$warn_line" ] && echo "AI generation failed for $provider/$model: $warn_line" >&2
                else
                    echo "AI generation failed for $provider/$model: empty response" >&2
                fi
            fi
        else
            provider_rc=$?
            result=""
            if [ "$provider_rc" -eq 124 ]; then
                echo "AI generation failed for $provider/$model: timed out after ${HOOK_AI_TIMEOUT:-20s}" >&2
            elif [ -s "$tmp_err" ]; then
                warn_line="$(grep -v '^$' "$tmp_err" | tail -1 | tr -d '\r')"
                [ -n "$warn_line" ] && echo "AI generation failed for $provider/$model: $warn_line" >&2
            else
                echo "AI generation failed for $provider/$model: exit code $provider_rc" >&2
            fi
        fi
        rm -f "$tmp_err"

        if [ -n "$result" ]; then
            break
        fi

        echo "Trying next configured model..." >&2
    done < <(config_read)

    if [ -n "$result" ]; then
        { echo "${ticket:+$ticket }$result"; echo "$existing"; } > "$file"
    else
        if [ -n "$ticket" ]; then
            { echo "$ticket "; echo "$existing"; } > "$file"
        fi
        echo "AI generation unavailable, opening editor." >&2
    fi

    return 0
}
