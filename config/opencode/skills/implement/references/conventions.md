# Project Convention Discovery

Conventions are **project-specific** and must be discovered from the project being worked on —
never assumed from another project. This guide defines what conventions the `implement` workflow
needs and how to resolve them for the current repository.

## Resolution Order

Resolve each convention using the first source that provides it:

1. **`CONVENTIONS.md`** at the project root — if present and complete, use it directly and skip
   scanning. If present but missing some items, use what it has and scan only for the gaps.
2. **`AGENTS.md` / `CLAUDE.md`** (and any files they reference) — agent-facing docs often capture
   build/test commands, branch and PR rules.
3. **Project scan** — derive remaining conventions from the sources listed in the table below.
   Delegate to a sub-agent (e.g. `explore`) when multiple sources need to be searched.

After scanning, if `CONVENTIONS.md` did not already exist or was incomplete, **ask the user**
whether to save the derived conventions to `CONVENTIONS.md` and reference it from
`AGENTS.md` / `CLAUDE.md`. Only write those files with explicit consent.

## Conventions Needed

| Convention | What to determine | Where to look |
|---|---|---|
| **Issue tracker** | Jira site / `cloudId`, project key(s) | `CONVENTIONS.md`, `AGENTS.md`/`CLAUDE.md`, existing branch/commit ticket prefixes, ask the user |
| **Repository** | GitHub `owner/repo` for `gh` | `git remote -v` |
| **Base / reference branch** | Branch to base work on and target PRs at | `git symbolic-ref refs/remotes/origin/HEAD`, default branch, `CONTRIBUTING.md`, ask the user |
| **Branch naming** | Pattern (e.g. `{TICKET-ID}-{slug}`, `feature/...`) | Recent branches (`git branch -a`, `git log --all`), `CONTRIBUTING.md`, hooks |
| **Commit message format** | Prefix/structure (e.g. `[TICKET-ID] Title`, Conventional Commits) | `prepare-commit-msg` / `commit-msg` hooks (`.git/hooks/`, `.husky/`), `commitlint` config, recent `git log`, `git-master` skill, `CONTRIBUTING.md` |
| **PR template** | Body structure for the PR | `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/PULL_REQUEST_TEMPLATE/` |
| **Quality gates** | Lint / test / build / format commands that must pass | `README.md`, `CONTRIBUTING.md`, `package.json` scripts, `Makefile`, `Rakefile`, `bin/`, CI workflows (`.github/workflows/`) |
| **Command entrypoint** | How commands run (plain, `bin/` wrapper, Docker/compose, package manager) | `bin/` scripts, `docker-compose.yml`, `Makefile`, `README.md` |
| **Testing conventions** | Test framework, dirs, naming, style | Existing test files/dirs, test config, docs |
| **Git hooks** | What hooks enforce (so commits aren't bypassed/blocked unexpectedly) | `.git/hooks/`, `.husky/`, `lefthook`/`pre-commit` config |

## Discovery Notes

- **PR template**: When `.github/pull_request_template.md` (or a variant) exists, use it verbatim
  as the PR body structure, filling each section. Only fall back to a generic body if no template
  is found.
- **Commit messages**: Prefer the project's own signal. If a `prepare-commit-msg`/`commit-msg`
  hook auto-formats messages, mirror its format and remember whether `-m` commits bypass it. Else
  infer the format from recent `git log` history or the `git-master` skill.
- **Quality gates**: Run only commands that actually exist in the project. If none are discoverable,
  ask the user for the lint/test commands rather than guessing.
- **Submodules / sub-projects**: If the change spans a submodule or nested package, follow that
  sub-project's own commit/push flow before updating the parent reference.

## CONVENTIONS.md Shape (when saving)

When the user agrees to persist discovered conventions, write a `CONVENTIONS.md` covering the rows
above. Suggested sections: Issue Tracker, Repository, Branching, Commit Messages, PR Template,
Quality Gates, Command Entrypoint, Testing, Git Hooks. Then add a reference line to
`AGENTS.md` / `CLAUDE.md` pointing at it (e.g. "See `CONVENTIONS.md` for project conventions.").
