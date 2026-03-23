#!/usr/bin/env bash
#
# Setup script for new machines
# Usage: curl -fsSL https://raw.githubusercontent.com/mauriciozaffari/dotfiles/main/setup.sh | bash
#
set -euo pipefail

info()  { printf "\033[0;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[0;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[0;33m[warn]\033[0m  %s\n" "$1"; }
fail()  { printf "\033[0;31m[fail]\033[0m  %s\n" "$1"; exit 1; }

DOTFILES_REPO="https://github.com/mauriciozaffari/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

echo ""
echo "============================================"
echo "  Dotfiles Setup"
echo "============================================"
echo ""

# --------------------------------------------------
# 0. Collect user info
# --------------------------------------------------
read -rp "Git name (e.g. Your Name): " GIT_NAME
read -rp "Git email (e.g. you@example.com): " GIT_EMAIL

if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
    fail "Git name and email are required"
fi

# --------------------------------------------------
# 1. System packages
# --------------------------------------------------
info "Installing system packages..."
sudo apt update -qq
sudo apt install -y -qq \
    git curl wget \
    zsh \
    build-essential \
    htop \
    docker.io docker-compose-v2 \
    gh \
    >/dev/null 2>&1
ok "System packages installed"

# --------------------------------------------------
# 2. Oh-My-Zsh
# --------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh-My-Zsh..."
    RUNZSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh-My-Zsh installed"
else
    ok "Oh-My-Zsh already installed"
fi

# --------------------------------------------------
# 3. Powerlevel10k
# --------------------------------------------------
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ok "Powerlevel10k installed"
else
    ok "Powerlevel10k already installed"
fi

# --------------------------------------------------
# 4. Zsh plugins
# --------------------------------------------------
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    info "Installing zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    ok "zsh-autosuggestions installed"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
    info "Installing zsh-completions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
    ok "zsh-completions installed"
fi

# --------------------------------------------------
# 5. asdf version manager (pre-compiled binary)
# --------------------------------------------------
ASDF_VERSION="v0.16.0"
ASDF_BIN_DIR="$HOME/.local/bin"

if command -v asdf &>/dev/null; then
    ok "asdf already installed ($(asdf version))"
else
    info "Installing asdf ${ASDF_VERSION}..."
    mkdir -p "$ASDF_BIN_DIR"

    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
    esac
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"

    ASDF_URL="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-${OS}-${ARCH}.tar.gz"
    info "Downloading from $ASDF_URL"
    curl -fsSL "$ASDF_URL" | tar -xz -C "$ASDF_BIN_DIR"
    chmod +x "$ASDF_BIN_DIR/asdf"
    export PATH="$ASDF_BIN_DIR:$PATH"
    ok "asdf ${ASDF_VERSION} installed to $ASDF_BIN_DIR"
fi

# --------------------------------------------------
# 6. Clone dotfiles
# --------------------------------------------------
if [ -d "$DOTFILES_DIR" ]; then
    info "Dotfiles directory exists, pulling latest..."
    git -C "$DOTFILES_DIR" pull --ff-only
    ok "Dotfiles updated"
else
    info "Cloning dotfiles..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    ok "Dotfiles cloned"
fi

# --------------------------------------------------
# 7. Deploy dotfiles
# --------------------------------------------------
info "Deploying dotfiles..."
bash "$DOTFILES_DIR/deploy.sh"

# --------------------------------------------------
# 8. Configure git identity
# --------------------------------------------------
info "Configuring git identity..."
cat > "$HOME/.gitconfig.local" <<EOF
[user]
        name = $GIT_NAME
        email = $GIT_EMAIL
EOF
chmod 600 "$HOME/.gitconfig.local"
ok "Git identity saved to ~/.gitconfig.local"

# --------------------------------------------------
# 9. Set default shell
# --------------------------------------------------
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Setting Zsh as default shell..."
    chsh -s "$(which zsh)"
    ok "Default shell changed to Zsh"
else
    ok "Zsh is already the default shell"
fi

# --------------------------------------------------
# 10. Docker group
# --------------------------------------------------
if ! groups | grep -q docker; then
    info "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
    warn "Log out and back in for docker group to take effect"
else
    ok "User already in docker group"
fi

# --------------------------------------------------
# 11. SSH key
# --------------------------------------------------
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    echo ""
    echo "No SSH key found at ~/.ssh/id_ed25519"
    echo ""
    echo "  1) Generate a new key"
    echo "  2) Copy from another system (paste private key)"
    echo "  3) Skip for now"
    echo ""
    read -rp "Choose [1/2/3]: " SSH_CHOICE

    case "$SSH_CHOICE" in
        1)
            info "Generating SSH key..."
            ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$HOME/.ssh/id_ed25519" -N ""
            ok "SSH key generated at ~/.ssh/id_ed25519"
            echo ""
            info "Add this public key to GitHub:"
            cat "$HOME/.ssh/id_ed25519.pub"
            echo ""
            ;;
        2)
            echo ""
            info "Paste your private key below, then press Enter and Ctrl+D:"
            cat > "$HOME/.ssh/id_ed25519"
            chmod 600 "$HOME/.ssh/id_ed25519"
            ok "Private key saved to ~/.ssh/id_ed25519"
            echo ""
            read -rp "Paste your public key (or press Enter to derive it): " SSH_PUB
            if [ -n "$SSH_PUB" ]; then
                echo "$SSH_PUB" > "$HOME/.ssh/id_ed25519.pub"
            else
                ssh-keygen -y -f "$HOME/.ssh/id_ed25519" > "$HOME/.ssh/id_ed25519.pub"
            fi
            chmod 644 "$HOME/.ssh/id_ed25519.pub"
            ok "Public key saved to ~/.ssh/id_ed25519.pub"
            ;;
        *)
            warn "Skipping SSH key setup"
            ;;
    esac
else
    ok "SSH key already exists"
fi

# --------------------------------------------------
# 12. Install asdf plugins and versions
# --------------------------------------------------
export PATH="$HOME/.local/bin:${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

install_asdf_plugin() {
    local plugin="$1"
    if ! asdf plugin list 2>/dev/null | grep -q "^${plugin}$"; then
        info "Adding asdf plugin: $plugin"
        asdf plugin add "$plugin"
        ok "$plugin plugin added"
    else
        ok "$plugin plugin already installed"
    fi
}

if [ -f "$HOME/.tool-versions" ]; then
    info "Installing asdf plugins and versions from .tool-versions..."
    while read -r plugin _version; do
        [ -z "$plugin" ] && continue
        install_asdf_plugin "$plugin"
    done < "$HOME/.tool-versions"

    info "Installing tool versions (this may take a while)..."
    asdf install
    ok "All tool versions installed"
else
    warn "No .tool-versions found, skipping asdf installs"
fi

echo ""
echo "============================================"
ok "Setup complete!"
echo ""
info "Next steps:"
echo "  1. Edit ~/.secrets with your API keys"
echo "  2. Restart your terminal (or run: exec zsh)"
echo "============================================"
echo ""
