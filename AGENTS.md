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
- `~/.docker_helpers` - Docker Compose aliases
- `~/.config/` - XDG config directory

## Useful Aliases

```bash
dev          # cd ~/development
zshconfig    # edit and reload .zshrc
dc           # docker compose
dcr          # docker compose run --rm --entrypoint=''
d            # run command in app/api container
```

## Subagent Delegation: Background Mode Rules

Heavyweight subagents (`plan`, `oracle`, `deep`) spawn nested subagents and
background tasks that can run 10+ minutes. Synchronous mode
(`run_in_background=false`) blocks the parent turn with no progress feedback,
causing apparent freezes and user-initiated cancellations.

- `plan`, `oracle`, `deep`: ALWAYS `run_in_background=true`. Collect results
  via `background_output(task_id="bg_...")` after the `<system-reminder>`.
- `explore`, `librarian`: ALWAYS `run_in_background=true` (already the default).
- `quick`, `unspecified-low`: `run_in_background=false` is fine (fast, single-shot).
- `unspecified-high` (implementation): `run_in_background=true` for parallel fan-out.

If a synchronous task call returns `Tool execution aborted`, recover the
child session via `session_search`/`session_read` instead of re-spawning.

## Projects

Development projects live in `~/development/`. Navigate there with `dev` alias.
