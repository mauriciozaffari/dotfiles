# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Context

This is a home directory, not a project repository. Sessions here typically involve:
- System configuration and troubleshooting
- Shell/terminal customization
- General AI assistance

## Key Configuration Files

- `~/.zshrc` - Shell configuration
- `~/.gitconfig` - Git configuration
- `~/.tool-versions` - asdf version pinning
- `~/.docker_helpers` - Docker/docker-compose aliases
- `~/.config/` - XDG config directory

## Useful Aliases

```bash
dev          # cd ~/development
zshconfig    # edit and reload .zshrc
dc           # docker-compose
dcr          # docker-compose run --rm --entrypoint=''
d            # run command in app/api container
```

## Projects

Development projects live in `~/development/`. Navigate there with `dev` alias.
