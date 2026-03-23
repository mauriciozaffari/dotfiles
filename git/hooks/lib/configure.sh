#!/usr/bin/env bash
# Interactive configuration wizard for AI commit messages

# Wrapper that ensures proper terminal handling.
# Git hooks run with stdin connected to /dev/null, so read doesn't work.
# We redirect the entire function from /dev/tty and reset terminal settings
# so that backspace, arrow keys, and Ctrl-C work correctly.
run_configure() {
    # Save terminal state and ensure it's restored on exit
    local tty_settings
    tty_settings="$(stty -g </dev/tty 2>/dev/null)" || true
    stty sane </dev/tty 2>/dev/null || true

    _run_configure_inner </dev/tty
    local rc=$?

    # Restore terminal state
    if [ -n "$tty_settings" ]; then
        stty "$tty_settings" </dev/tty 2>/dev/null || true
    fi

    return $rc
}

_ask() {
    local prompt="$1" var="$2"
    # -e enables readline (backspace, arrows, history)
    read -re -p "$prompt" "$var"
}

_run_configure_inner() {
    local project_name
    project_name="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"

    echo "" >&2
    echo "Configuring AI commit messages for: $project_name" >&2
    echo "════════════════════════════════════════════════════" >&2

    # ── Step 1: Select tools ──────────────────────────
    echo "" >&2
    echo "Available tools:" >&2

    local i=1
    local provider_status=()
    for provider in "${AVAILABLE_PROVIDERS[@]}"; do
        local name status
        name="$(provider_${provider}_name)"
        if "provider_${provider}_installed"; then
            status="installed"
        else
            status="not installed"
        fi
        provider_status+=("$status")
        printf "  %d) [%s] %s\n" "$i" "$status" "$name" >&2
        i=$((i + 1))
    done

    echo "" >&2
    local tool_selection
    _ask "Select tools (comma-separated, e.g. 1,2): " tool_selection

    local selected_providers=()
    IFS=',' read -ra selections <<< "$tool_selection"
    for sel in "${selections[@]}"; do
        sel="$(echo "$sel" | tr -d ' ')"
        [ -z "$sel" ] && continue
        local idx=$((sel - 1))
        if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#AVAILABLE_PROVIDERS[@]}" ]; then
            echo "  Invalid selection: $sel" >&2
            continue
        fi

        local provider="${AVAILABLE_PROVIDERS[$idx]}"

        # Offer to install if not present
        if [ "${provider_status[$idx]}" = "not installed" ]; then
            echo "" >&2
            echo "  $(provider_${provider}_name) is not installed." >&2
            "provider_${provider}_install"
            if ! "provider_${provider}_installed"; then
                echo "  Skipping $(provider_${provider}_name) (installation failed)" >&2
                continue
            fi
        fi

        selected_providers+=("$provider")
    done

    if [ ${#selected_providers[@]} -eq 0 ]; then
        echo "No tools selected. Aborting configuration." >&2
        return 1
    fi

    # ── Step 2: Auth (for providers that support it) ──
    for provider in "${selected_providers[@]}"; do
        if [ "$provider" = "opencode" ]; then
            echo "" >&2
            echo "$(provider_${provider}_name): authenticate with providers?" >&2
            local auth_yn
            _ask "  Would you like to log in to a service? [y/N]: " auth_yn
            if [[ "$auth_yn" =~ ^[yY]$ ]]; then
                "provider_${provider}_auth"
            fi
        fi
    done

    # ── Step 3: Select models per tool ────────────────
    local all_entries=()  # "provider:model" pairs

    for provider in "${selected_providers[@]}"; do
        local name
        name="$(provider_${provider}_name)"

        echo "" >&2
        echo "Available $name models:" >&2

        local models=()
        while IFS= read -r model; do
            [ -z "$model" ] && continue
            models+=("$model")
        done < <("provider_${provider}_models")

        if [ ${#models[@]} -eq 0 ]; then
            echo "  No models available for $name" >&2
            continue
        fi

        local j=1
        for model in "${models[@]}"; do
            printf "  %d) %s\n" "$j" "$model" >&2
            j=$((j + 1))
        done

        echo "" >&2
        local model_selection
        _ask "Select models (comma-separated): " model_selection

        IFS=',' read -ra model_sels <<< "$model_selection"
        for msel in "${model_sels[@]}"; do
            msel="$(echo "$msel" | tr -d ' ')"
            [ -z "$msel" ] && continue
            local midx=$((msel - 1))
            if [ "$midx" -ge 0 ] && [ "$midx" -lt "${#models[@]}" ]; then
                all_entries+=("${provider}:${models[$midx]}")
            fi
        done
    done

    if [ ${#all_entries[@]} -eq 0 ]; then
        echo "No models selected. Aborting configuration." >&2
        return 1
    fi

    # ── Step 4: Priority ordering ─────────────────────
    echo "" >&2
    echo "Selected provider/models:" >&2
    local k=1
    for entry in "${all_entries[@]}"; do
        local p="${entry%%:*}" m="${entry#*:}"
        printf "  %d) %s / %s\n" "$k" "$(provider_${p}_name)" "$m" >&2
        k=$((k + 1))
    done

    local max_priority=5
    if [ ${#all_entries[@]} -lt "$max_priority" ]; then
        max_priority=${#all_entries[@]}
    fi

    echo "" >&2
    echo "Choose 1-${max_priority} models in priority order." >&2
    local priority_input
    _ask "Enter numbers in order (e.g. 2,1,3): " priority_input

    local ordered_entries=()
    local seen=()
    IFS=',' read -ra prio_sels <<< "$priority_input"
    for psel in "${prio_sels[@]}"; do
        psel="$(echo "$psel" | tr -d ' ')"
        [ -z "$psel" ] && continue
        local pidx=$((psel - 1))
        if [ "$pidx" -ge 0 ] && [ "$pidx" -lt "${#all_entries[@]}" ]; then
            # Skip duplicates
            local already=0
            for s in "${seen[@]}"; do
                [ "$s" = "$pidx" ] && already=1
            done
            if [ "$already" -eq 0 ]; then
                ordered_entries+=("${all_entries[$pidx]}")
                seen+=("$pidx")
            fi
        fi
        # Cap at 5
        [ ${#ordered_entries[@]} -ge 5 ] && break
    done

    if [ ${#ordered_entries[@]} -eq 0 ]; then
        # Default to original order, capped at 5
        for entry in "${all_entries[@]}"; do
            ordered_entries+=("$entry")
            [ ${#ordered_entries[@]} -ge 5 ] && break
        done
    fi

    # ── Step 5: Confirm and save ──────────────────────
    echo "" >&2
    echo "Final priority:" >&2
    local n=1
    for entry in "${ordered_entries[@]}"; do
        local p="${entry%%:*}" m="${entry#*:}"
        printf "  %d. %s / %s\n" "$n" "$(provider_${p}_name)" "$m" >&2
        n=$((n + 1))
    done

    echo "" >&2
    local save_yn
    _ask "Save? [Y/n]: " save_yn
    if [[ "$save_yn" =~ ^[nN]$ ]]; then
        echo "Configuration cancelled." >&2
        return 1
    fi

    local conf_content=""
    for entry in "${ordered_entries[@]}"; do
        conf_content+="${entry}"$'\n'
    done

    config_write "$conf_content"
    echo "Configuration saved." >&2
}
