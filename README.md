# Dotfiles

Personal dotfiles for Debian/Ubuntu systems with Zsh, Oh-My-Zsh, and Powerlevel10k.

## Quick Setup (New Machine)

```bash
curl -fsSL https://raw.githubusercontent.com/mauriciozaffari/dotfiles/main/setup.sh | bash
```

This installs system packages, Oh-My-Zsh, Powerlevel10k, asdf, clones this repo, deploys all configs, and configures git identity.

## Deploy (Existing Machine)

After making changes to files in this repo:

```bash
~/dotfiles/deploy.sh
```

This creates symlinks from your home directory to the repo files. Any existing files that would be overwritten are backed up to `~/.dotfiles_backup/<timestamp>/` with a manifest for rollback.

## Rollback

To undo a deployment and restore previous files:

```bash
~/dotfiles/deploy.sh --rollback
```

This lists all available backups and lets you pick one to restore.

## Structure

```
dotfiles/
├── shell/
│   ├── zshrc              -> ~/.zshrc
│   └── docker_helpers     -> ~/.docker_helpers
├── git/
│   ├── gitconfig          -> ~/.gitconfig
│   └── gitignore          -> ~/.gitignore
├── tools/
│   ├── asdfrc             -> ~/.asdfrc
│   ├── tool-versions      -> ~/.tool-versions
│   └── gemrc              -> ~/.gemrc
├── ssh/
│   └── config             -> ~/.ssh/config
├── config/
│   ├── git/ignore         -> ~/.config/git/ignore
│   ├── htop/htoprc        -> ~/.config/htop/htoprc
│   └── opencode/          -> ~/.config/opencode/
│       ├── AGENTS.md
│       ├── opencode.jsonc
│       ├── plugin/
│       ├── agent/
│       └── skills/
├── AGENTS.md              -> ~/AGENTS.md (+ symlinks: ~/CLAUDE.md, ~/GEMINI.md)
├── secrets.example        (template for ~/.secrets)
├── deploy.sh              (symlink configs to system)
└── setup.sh               (full setup for new machines)
```

## Secrets

Secrets are stored in `~/.secrets` (never committed). The file is sourced by `.zshrc` at startup.

```bash
# Create from template
cp secrets.example ~/.secrets
chmod 600 ~/.secrets
# Edit with your values
$EDITOR ~/.secrets
```

## Git Identity

Git user name and email are not stored in the repo. The setup script prompts for them. To set manually:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

## Stack

- **Shell**: Zsh + Oh-My-Zsh + Powerlevel10k
- **Version Manager**: asdf (Node.js, Ruby, uv)
- **Containers**: Docker + docker-compose
- **AI Tools**: OpenCode, Claude Code
