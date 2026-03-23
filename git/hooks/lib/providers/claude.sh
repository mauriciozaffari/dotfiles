#!/usr/bin/env bash
# Provider: Claude CLI (claude code)

provider_claude_name() { echo "Claude CLI"; }

provider_claude_installed() {
    command -v claude &>/dev/null
}

provider_claude_install() {
    echo "Install Claude CLI from: https://docs.anthropic.com/en/docs/claude-code"
    echo "  npm install -g @anthropic-ai/claude-code"
    read -re -p "Install now? [y/N]: " yn
    if [[ "$yn" =~ ^[yY]$ ]]; then
        npm install -g @anthropic-ai/claude-code
        return $?
    fi
    return 1
}

provider_claude_auth() {
    : # Claude CLI handles auth on first use
}

provider_claude_models() {
    cat <<'EOF'
haiku
sonnet
opus
EOF
}

provider_claude_generate() {
    local model="$1" prompt="$2"
    timeout "${HOOK_AI_TIMEOUT:-20s}" \
        claude --print --model "$model" --effort low 2>/dev/null <<< "$prompt"
}
