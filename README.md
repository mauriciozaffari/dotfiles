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

This creates symlinks from your home directory to the repo files. Any existing files that would be overwritten are backed up to `~/.dotfiles/backups/<timestamp>/` with a manifest for rollback.

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
│   ├── gitignore          -> ~/.gitignore
│   └── hooks/             -> project .git/hooks/ (symlinked per-project)
│       ├── pre-commit
│       ├── prepare-commit-msg
│       └── lib/
│           ├── config.sh, configure.sh, diff.sh, prompt.sh, sanitize.sh, ticket.sh
│           └── providers/  (opencode.sh, claude.sh, codex.sh)
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

## Git Hooks

The deploy script manages shared git hooks across projects in `~/development/`.

**Hooks provided:**
- **`pre-commit`** -- Blocks commits with failing RSpec tests or RuboCop offenses
- **`prepare-commit-msg`** -- Extracts ticket numbers from branch names and generates AI commit messages

**How it works:**
- Hook entry points are symlinked into each project's `.git/hooks/`
- They resolve back to `dotfiles/git/hooks/lib/` for the actual logic
- Edits to dotfiles hooks propagate instantly to all projects (no re-deploy needed)

**AI commit messages:**
On first commit in a project, a configuration wizard runs:
1. Select which AI tools to use (OpenCode, Claude CLI, Codex CLI)
2. Install any missing tools
3. Authenticate with providers (e.g., OpenCode OAuth)
4. Choose models per tool
5. Set priority order (1-5 provider/model pairs)

Config is saved per-project in `.git/commit-ai.conf`. The hook tries each provider/model in priority order, using the lowest reasoning variant for speed.

To reconfigure a project, delete `.git/commit-ai.conf` and commit again.

**Deploy state** is stored in `~/.dotfiles/`:
- `hooks_installed` -- projects with hooks installed
- `hooks_skipped` -- projects permanently skipped

To re-enable a permanently skipped project, remove its line from `~/.dotfiles/hooks_skipped`.

## Git Identity

Git user name and email are not stored in the repo. The repo-managed `~/.gitconfig` includes `~/.gitconfig.local`, and the setup script writes identity there. To set manually:

```bash
cat > ~/.gitconfig.local <<'EOF'
[user]
        name = Your Name
        email = you@example.com
EOF
```

## Stack

- **Shell**: Zsh + Oh-My-Zsh + Powerlevel10k
- **Version Manager**: asdf (Node.js, Ruby, uv)
- **Containers**: Docker + docker-compose
- **AI Tools**: OpenCode, Claude Code
