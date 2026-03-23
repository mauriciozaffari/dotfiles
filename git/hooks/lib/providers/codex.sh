#!/usr/bin/env bash
# Provider: OpenAI Codex CLI

provider_codex_name() { echo "Codex CLI"; }

provider_codex_installed() {
    command -v codex &>/dev/null
}

provider_codex_install() {
    echo "Install Codex CLI from: https://github.com/openai/codex"
    echo "  npm install -g @openai/codex"
    read -re -p "Install now? [y/N]: " yn
    if [[ "$yn" =~ ^[yY]$ ]]; then
        npm install -g @openai/codex
        return $?
    fi
    return 1
}

provider_codex_auth() {
    : # Codex CLI uses OPENAI_API_KEY or oauth
}

provider_codex_models() {
    cat <<'EOF'
codex-mini
o4-mini
o3
gpt-4.1
EOF
}

provider_codex_generate() {
    local model="$1" prompt="$2"
    local tmpout tmperr
    tmpout="$(mktemp)"; tmperr="$(mktemp)"
    timeout "${HOOK_AI_TIMEOUT:-20s}" \
        codex exec --config model_reasoning_effort=low --model "$model" -o "$tmpout" - <<< "$prompt" 2>"$tmperr" >/dev/null
    local rc=$?
    if [ $rc -eq 0 ] && [ -s "$tmpout" ]; then
        cat "$tmpout"
    fi
    rm -f "$tmpout" "$tmperr"
    return $rc
}
