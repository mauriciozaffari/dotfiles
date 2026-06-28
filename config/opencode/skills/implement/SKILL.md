---
name: implement
description: >-
  End-to-end Jira ticket implementation harness. Fetches ticket
  from Jira, creates an implementation plan, executes it with proper branching,
  commits, quality gates, and opens a PR. Use when the user says "implement
  TICKET-ID", "work on TICKET-ID", "pick up TICKET-ID", "start TICKET-ID",
  or provides a Jira ticket key (e.g., PREFIX-1810, TICKET-450) with implementation
  intent. Covers bugs, tasks, stories, and any other Jira issue type.
---

# Implement

Orchestrate full Jira-ticket-to-PR workflow: discover conventions → fetch → plan → branch →
implement → test → PR.

This skill is **repo-agnostic**. All project-specific details (branch naming, commit format, PR
template, quality gates, commands, issue tracker) are **discovered from the current project**, not
assumed. Read [references/conventions.md](references/conventions.md) — it defines what conventions
are needed and how to resolve them — and complete Step 0 before doing any project work.

## Workflow

0. **Discover conventions** for the current project
1. **Fetch ticket** from Jira
2. **Analyze** ticket and create implementation plan
3. **Present plan** to user, gather feedback
4. **Create branch** from reference branch, push immediately
5. **Implement** changes, committing and pushing on each logical iteration
6. **Finalize** — run quality gates, fix failures, open PR

---

## Step 0: Discover Project Conventions

Resolve the conventions defined in [references/conventions.md](references/conventions.md) for the
current repository, using this order:

1. **`CONVENTIONS.md`** at the project root — if present and complete, use it directly and skip the
   scan. If present but incomplete, use what it has and scan only for the missing items.
2. **`AGENTS.md` / `CLAUDE.md`** (and files they reference) for build/test/branch/PR rules.
3. **Scan the project** for anything still unresolved. Delegate a broad scan to an `explore`
   sub-agent when several sources must be checked (git remote, recent branches/commits, git hooks,
   `.github/`, CI workflows, package manifests, README/CONTRIBUTING, test dirs).

Key sources:
- **Issue tracker** (Jira site/`cloudId`, project keys) — from `CONVENTIONS.md`/agent docs, existing
  ticket prefixes in branches/commits, or ask the user.
- **Repository** — `git remote -v` for the `gh` target.
- **Base branch + branch naming** — default branch and recent branch names.
- **Commit format** — `prepare-commit-msg`/`commit-msg` hooks, `commitlint`, recent `git log`,
  the `git-master` skill, or `CONTRIBUTING.md`.
- **PR template** — `.github/pull_request_template.md` (or variant) when present.
- **Quality gates + command entrypoint** — `package.json`/`Makefile`/`Rakefile`/`bin/`, CI
  workflows, README/CONTRIBUTING.

If `CONVENTIONS.md` did not exist or was incomplete, after deriving the conventions **ask the user**
whether to save them to `CONVENTIONS.md` and reference it from `AGENTS.md` / `CLAUDE.md`. Only write
those files with explicit consent.

If a required convention cannot be discovered (e.g. the Jira `cloudId` or quality-gate commands),
**ask the user** rather than guessing.

---

## Step 1: Fetch Ticket

Extract the ticket ID from the user message (e.g., `PREFIX-1810`).

Fetch the ticket using the Atlassian MCP, with the `cloudId` discovered in Step 0:

```
getJiraIssue(
  cloudId: "{discovered-site}.atlassian.net",
  issueIdOrKey: "{TICKET-ID}",
  responseContentFormat: "markdown"
)
```

Extract from the response:
- **Summary** (title)
- **Description** (full details, acceptance criteria)
- **Issue type** (Bug, Task, Story, Sub-task, etc.)
- **Priority**
- **Status** (should be To Do or In Progress)
- **Labels, components** (if present)
- **Parent** (if sub-task, fetch parent for broader context)
- **Linked issues** (if any, fetch for context)

If description is sparse, check for Confluence links or attachments and fetch those too.

## Step 2: Analyze and Plan

Based on ticket type, adapt the planning approach:

- **Bug**: Identify reproduction steps, locate faulty code, plan minimal fix + regression test.
- **Story/Task**: Break into implementation steps, identify affected files/modules, plan tests.
- **Sub-task**: Understand parent story context, scope narrowly to the sub-task.

Use explore agents to search the codebase for relevant files, existing patterns, and related code.
Use librarian agents if unfamiliar libraries or APIs are involved.
Consult Oracle for non-trivial architecture decisions.

Build a plan with:
- Files to create/modify
- Approach summary (1-3 sentences)
- Ordered implementation steps
- Test strategy (what specs to add/modify)
- Risk assessment (none/low/high)

## Step 3: Present Plan and Gather Feedback

Present the plan to the user clearly:

```
## Implementation Plan for {TICKET-ID}

**Ticket**: {summary}
**Type**: {issue_type} | **Priority**: {priority}

**Approach**: {1-3 sentence summary}

**Steps**:
1. {step with files involved}
2. {step with files involved}
...

**Tests**: {what will be tested and how}
**Risk**: {none|low|high} — {brief reason}

**Questions** (if any):
- {clarifying question}
```

Wait for user confirmation. Accept additional context, files, or corrections.
Do NOT proceed until the user explicitly agrees.

## Step 4: Create Branch

Once approved:

1. Ensure working directory is clean (stash or warn if dirty).
2. Checkout and pull the latest **base branch discovered in Step 0** (e.g. `main`, `develop`):
   ```bash
   git checkout {base-branch} && git pull origin {base-branch}
   ```
3. Create and push the feature branch using the **discovered branch-naming pattern**:
   ```bash
   git checkout -b {branch-name}
   git push -u origin {branch-name}
   ```

Apply the project's discovered branch-naming convention. If none is documented, default to:
- Ticket ID uppercase: `PREFIX-1810`
- Summary slug lowercase, hyphen-separated, concise (3-5 words max)
- Example: `PREFIX-1810-release-windows-sync`

## Step 5: Implement

Execute the plan step by step. After each logical unit of work:

1. Stage and commit using the **commit format discovered in Step 0**:
   ```bash
   git add -A
   git commit -m "{message in the project's commit format}"
   ```
2. Push to remote:
   ```bash
   git push
   ```

**Commit guidelines**:
- Follow the project's discovered commit-message format (e.g. `[TICKET-ID] Title`, Conventional
  Commits). If a `prepare-commit-msg`/`commit-msg` hook formats messages, mirror it — and note that
  hooks which auto-prepend ticket IDs typically only run for interactive commits, so include the
  prefix manually when using `-m`.
- Present tense, action-oriented: "Add", "Fix", "Update", "Remove".
- Bullets (if used) describe WHAT changed, not HOW.

**During implementation**:
- Follow existing codebase patterns. Read similar files first.
- Run the project's discovered formatter/linter auto-fix command periodically to clear style issues
  before they block commits.
- Write tests alongside code, not as an afterthought.
- If the change spans a submodule or nested sub-project, commit inside that sub-project first, then
  update its reference in the parent repo.

**If a pre-commit / lint hook blocks a commit**:
- Fix the issue, do not bypass with `--no-verify`.
- Re-run the project's auto-fix command for auto-fixable offenses.

## Step 6: Finalize

When the user is satisfied with the implementation:

### 6a. Commit remaining work

Commit and push any remaining changes using the project's discovered commit format:

```bash
git add -A
git commit -m "{final change description in the project's commit format}"
git push
```

### 6b. Run quality gates

Run the **quality-gate commands discovered in Step 0** (lint, test, build/format — via the project's
command entrypoint). Run only commands that exist in the project; if none were discoverable, ask the
user for them.

- Run the gates relevant to what changed (e.g. backend vs. frontend/sub-project commands).
- For larger changes, run the fuller suite rather than a targeted subset.

Iterate: fix → commit → re-run until all gates pass.

### 6c. Open PR

Create a PR targeting the **base branch** with `gh`. Use the **PR template discovered in Step 0**.

If `.github/pull_request_template.md` (or a variant) exists, use it verbatim as the body, filling in
each section. Otherwise fall back to a concise generic body:

```bash
gh pr create --base {base-branch} --title "{PR title in commit style}" --body "$(cat <<'EOF'
## Changes
{What was changed and WHY — derived from ticket + implementation}

## How to review
{Specific review guidance — what to look for, expected behavior}

## Risks
{none | low | high} — {brief reason}
EOF
)"
```

- PR title: match the project's commit/title style (e.g. `[{TICKET-ID}] {summary}`).
- Changes section: describe what AND why, derived from the ticket description and actual changes.
- How to review: be specific — mention endpoints to test, pages to check, edge cases.
- Risks: reflect the risk assessment from the plan, in whatever shape the template expects.

### 6d. Report completion

Provide the user with:
- PR URL
- Summary of what was implemented
- Any remaining follow-ups or known limitations
