#!/usr/bin/env bash
# Provider: OpenCode

provider_opencode_name() { echo "OpenCode"; }

provider_opencode_installed() {
    command -v opencode &>/dev/null
}

provider_opencode_install() {
    echo "Install OpenCode from: https://opencode.ai"
    echo "  curl -fsSL https://opencode.ai/install | bash"
    read -re -p "Install now? [y/N]: " yn
    if [[ "$yn" =~ ^[yY]$ ]]; then
        curl -fsSL https://opencode.ai/install | bash
        return $?
    fi
    return 1
}

provider_opencode_auth() {
    echo ""
    echo "  Current providers:"
    opencode providers list 2>&1 | sed 's/^/    /'
    echo ""
    read -re -p "  Log in to a provider? [y/N]: " yn
    while [[ "$yn" =~ ^[yY]$ ]]; do
        opencode providers login
        echo ""
        read -re -p "  Log in to another provider? [y/N]: " yn
    done
}

provider_opencode_models() {
    opencode models 2>/dev/null | grep -v 'embedding\|live\|tts\|image\|free$' | sort
}

provider_opencode_generate() {
    local model="$1" prompt="$2"
    timeout "${HOOK_AI_TIMEOUT:-20s}" \
        opencode run --model "$model" --variant low "$prompt" </dev/null 2>/dev/null
}
