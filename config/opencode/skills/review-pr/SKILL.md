---
name: review-pr
description: Review a GitHub pull request end-to-end and produce specific, actionable change requests classified as "required" or "good_to_have". Use when the user invokes the /review-pr command with a PR link, says "review this PR", "review pull request", or asks for a code review on a GitHub PR URL. Detects PR ownership via the gh CLI — for the user's own PRs, outputs findings locally; for collaborator PRs, presents findings as approve/reject/change questions and then posts approved feedback as inline review comments at file and line (or as a general PR comment when not line-specific).
---

# Review PR

Produce rigorous, actionable code review feedback on a GitHub pull request. No praise, no summaries — only specific change requests with file/line anchors and `required` vs `good_to_have` classification.

## Inputs

- PR link or `owner/repo#number` from the user's `/review-pr` invocation.
- If missing, ask the user for the PR URL. Do not guess.

## Workflow

1. **Identify viewer and PR author** — determine ownership.
2. **Fetch PR metadata, diff, and existing review threads**.
3. **Check out the PR branch locally** so the codebase matches what's being reviewed.
4. **Understand the surrounding codebase** — patterns, conventions, related files.
5. **Analyze every changed file** against the checklist.
6. **Produce findings** as anchored change requests.
7. **Deliver** per ownership mode (self vs. collaborator).

---

## Step 1: Identify Viewer and Ownership

```bash
gh api user --jq .login                                  # viewer
gh pr view <pr> --json author,headRefName,baseRefName,headRepository,url,number,title,body
```

- `viewer == author.login` → **SELF mode**: emit findings to stdout only, do not post to GitHub.
- `viewer != author.login` → **COLLAB mode**: findings become questions, then post approved ones.

## Step 2: Fetch PR Context

```bash
gh pr view <pr> --json files,additions,deletions,baseRefOid,headRefOid,commits,reviewDecision
gh pr diff <pr>                                          # unified diff
gh pr view <pr> --comments                               # existing comments + review threads
```

Also fetch pending reviews/comments by the current viewer when possible:

```bash
gh api "repos/<owner>/<repo>/pulls/<pr>/reviews"         # inspect PENDING reviews
gh api "repos/<owner>/<repo>/pulls/<pr>/comments"        # inline review comments
```

Capture for every changed file:
- Path, status (added/modified/renamed/deleted), additions/deletions.
- The **file-level SHA** (`headRefOid`) — required later when posting inline comments.

Read every existing review thread and every pending review/comment from the current viewer. Do not repeat feedback that already exists.

**Never remove, delete, overwrite, or silently replace existing feedback** — including feedback in a `PENDING` review — without asking the user first via the `Question` tool. Treat pending feedback as user-owned work.

If existing feedback is invalid, stale, duplicated, too verbose, includes forbidden severity labels, lacks a valid file/line anchor, or otherwise does not conform to this skill's rules, propose a change instead of editing it unilaterally:

```
header:   "Existing feedback"
question: "This pending comment does not match the review rules: <short reason>. What should I do?\n\nCurrent: <current comment>\n\nProposed: <rewritten concise comment or deletion reason>"
options:
  - label: "Keep as-is"       description: "Leave the existing feedback unchanged"
  - label: "Replace"          description: "Use the proposed rewrite"
  - label: "Edit"             description: "I will provide a different version"
  - label: "Delete"           description: "Remove this existing feedback"
```

Only perform the selected action after the user chooses it. If `Question` is unavailable, stop; do not modify existing feedback.

## Step 3: Check Out the PR Locally

```bash
gh pr checkout <pr>
```

If the repo has submodules, update them:

```bash
git submodule update --init --recursive
```

Confirm working tree matches `headRefOid`. Note the merge-base against `baseRefName` for diff context.

## Step 4: Understand the Codebase

For each changed file or module, before critiquing:

- Read the full file (not just the diff hunk) to see the function/class in context.
- Fire `explore` agents in parallel for non-trivial PRs to surface:
  - Similar utilities, existing abstractions, test patterns, and naming conventions.
  - Other call sites of modified functions/classes.
- Read linter/formatter/test configs (`.rubocop.yml`, `eslint.config.*`, `pyproject.toml`, etc.) so feedback aligns with project standards.
- For submodule changes, inspect the referenced commit in the submodule repo.

Do not critique style that the project's configured linters already enforce or intentionally suppress.

## Step 5: Analyze Every Changed File

For **each** changed file, walk the checklist in [references/review-checklist.md](references/review-checklist.md). Review on **two passes** — do both before producing findings:

**Pass 1 — Correctness and conventions:**
- DRY violations vs. existing helpers/utilities.
- Inconsistencies with neighboring code (naming, structure, error handling, logging, i18n, test style).
- Correctness bugs, race conditions, off-by-one, null/empty handling.
- Missed edge cases (empty inputs, large inputs, unicode, timezones, concurrency, pagination, auth boundaries).
- Security (injection, authz, secrets, PII, SSRF, unsafe deserialization).
- Performance (N+1 queries, unbounded loops, unnecessary allocations, missing indexes).
- API/contract changes, migrations, backwards compatibility.
- Test coverage gaps for new branches/conditions.
- Submodule pointer changes: is the referenced commit on an allowed branch? does it include the expected changes?

**Pass 2 — Implementation shape (DRY / KISS / SOLID):**
Challenge the design, not just the bugs. For every non-trivial addition, ask:
- **DRY**: does this duplicate logic, data, or knowledge that already exists elsewhere in the repo? (Search for it — don't trust the diff in isolation.) Is the same concept encoded in two places that will drift?
- **KISS**: is this the simplest implementation that satisfies the requirement? Are there premature abstractions, unused generality, unnecessary indirection, flags with one caller, or config knobs with one value? Could a dumber, flatter version do the job?
- **SOLID**:
  - *Single responsibility* — does any new class/module/function do more than one thing? Is the name a conjunction ("and", "handler", "manager") that hints at smeared responsibility?
  - *Open/closed* — do new conditionals branch on type/role instead of polymorphism, forcing future edits inside this file?
  - *Liskov* — do subclasses/implementations weaken preconditions or strengthen postconditions vs. the parent/interface?
  - *Interface segregation* — are callers forced to depend on methods they don't use? Are new public methods actually called from outside?
  - *Dependency inversion* — does high-level logic reach directly into concrete infrastructure (DB, HTTP, clock, filesystem) where an existing abstraction is available?

Shape findings must reference concrete alternatives ("collapse `FooHandler` + `FooRunner` into `Foo.call` — the split is unused outside tests") — not abstract principles. Classify as `required` when the shape creates real maintenance or correctness risk, `good_to_have` when it's a clarity/consistency improvement.

Every finding must cite a concrete location. If a finding has no `file:line`, it must be phrased as a repo-level or PR-level general comment.

## Step 6: Produce Findings

Represent every finding as a structured item:

```
id:            F1
severity:      required | good_to_have
scope:         inline | general
file:          path/to/file.rb          # omit when scope=general
start_line:    120                      # first line of the range on `side`
line:          125                      # last line of the range on `side` (same as start_line for a single-line finding)
side:          RIGHT | LEFT             # RIGHT = PR head, LEFT = base
start_side:    RIGHT | LEFT             # defaults to same as `side`
title:         short imperative summary
body:          precise description of the problem
suggestion: |                           # optional; use GitHub suggestion block when a concrete replacement fits
  ```suggestion
  <replacement code>
  ```
```

`severity` is for the harness/user only. It helps group the `Question` prompts and the local ledger, but it must never be included in the GitHub review comment body, inline comment text, suggestion block, or review submission body.

Rules:
- **No praise.** No "nice work", no "LGTM overall", no recaps of what the PR does.
- Every item is imperative and specific ("Extract `normalize_email` — duplicated with `app/services/user_importer.rb:42`").
- Default to `required` for correctness, security, data integrity, broken tests, public API breakage, project-convention violations. Use `good_to_have` for style nits, refactor suggestions, or optional improvements.
- If nothing is wrong, emit zero findings. Do not manufacture issues.

**Be concise. Hard limits:**
- `title`: one line, imperative, ≤ 80 chars. No "please", no hedging ("maybe", "consider"), no rationale in the title.
- `body`: ≤ 3 sentences **or** ≤ 60 words, whichever comes first. Cut everything the reader can see from the diff or the cited references.
- Cite, don't quote. Reference the other location (`file.rb:42`) instead of pasting the duplicated code.
- Drop the motivation sentence ("this keeps things consistent", "removes two lambdas", "keeps formatting consistent with the rest of the admin UI") — the fix itself is the motivation.
- No restating what the code does. No "Both views define X, while Y already exists". Go straight to the ask.
- One finding = one ask. Split if you're adding "also…".
- Prefer a `suggestion:` block over prose whenever a concrete replacement fits — the code speaks for itself.

**Plain language. No jargon.**
- Write like you're talking to a teammate, not filing a formal report. Short words beat long ones.
- Drop Latin ("i.e.", "e.g.", "ergo", "viz.") — use "for example", "so", "that is".
- No design-principle name-dropping in the comment body ("violates SRP", "Liskov substitution", "inversion of control"). Describe the concrete problem in human terms ("this class does two unrelated things — split the DB write into its own service").
- No filler adverbs/adjectives: "clearly", "essentially", "simply", "obviously", "arguably", "robust", "elegant".
- Prefer active voice and concrete verbs: "replace X with Y", "move X to Y", "delete X", "inline X". Avoid "should be refactored", "could be improved", "might be worth considering".
- If a sentence needs a glossary to understand, rewrite it. Aim for a teammate who joined the team last week to understand the ask on first read.

Bad (verbose):
> Both override views define `platform_label = ->(p) { "#{p.name}(#{p.territory.name})" }`, while `Platform` already exposes `name_with_territory` and `name_with_territory_iso_code`, and nearby views use those methods for platform selects. Reusing the model helper removes two local lambdas and keeps platform-region formatting consistent with the rest of the admin UI.

Good (concise):
> Replace the local `platform_label` lambda with `Platform#name_with_territory` (also used in `app/views/.../_platform_select.html.haml`). Same in `_form.html.haml:4`.

## Step 7: Deliver

### SELF mode (viewer is the PR author)

Print findings to the terminal only. Do not call any write endpoints. Format:

```
# Review of <owner/repo#N> — <title>

## Required (N)
- [F1] path/to/file.rb:123 — <title>
      <body>
      suggestion: <one-line preview or "see block">

## Good to have (N)
- [F7] path/to/file.rb:200 — <title>
      <body>
```

End with: `Mode: SELF — no comments were posted.`

### COLLAB mode (viewer is not the PR author)

Present every finding as an **interactive question via the harness `Question` tool** (the MCP tool that renders clickable multiple-choice options) — do **not** print the finding as prose and ask the user to type a reply. The user must be able to click a choice.

For every finding, issue one `Question` call shaped like:

```
header:   "F1 file.rb:123 (required)"         # ≤30 chars — finding id, short anchor, severity
question: full finding body + suggestion block, shown as the question text
options:
  - label: "Approve"         description: "Post this comment as-is"
  - label: "Reject"          description: "Drop this comment"
  - label: "Edit"            description: "Revise title/body/suggestion before posting"
```

Batch-friendly: send findings in parallel `Question` calls (all required findings in one batch, all good_to_have in a second batch) so the user can answer them side by side. Do not gate each call on the previous answer unless findings are logically dependent.

The `Question` header may include `(required)` or `(good_to_have)` because the user needs that while deciding. Strip that severity label from the final GitHub comment before staging the pending review.

When the user picks **Edit**, follow up with a second `Question` asking which part to revise (title / body / suggestion / all) with clickable options, then a free-text prompt only for the revised content. Never require the user to type approve/reject.

Do not fall back to a prose "Action? (a)/(r)/(e)" prompt under any circumstance — if the `Question` tool is unavailable, stop and tell the user.

**Second-pass gate — before creating the pending review**, issue a `Question` asking whether the user wants a follow-up review pass on anything the first pass missed:

```
header:   "Anything else?"
question: "All findings decided. Do you want another review pass before I stage the pending review?"
options:
  - label: "No, stage the review"        description: "Proceed to create the pending review on GitHub"
  - label: "Focus: shape (DRY/KISS/SOLID)" description: "Re-review with design/architecture lens only"
  - label: "Focus: tests"                description: "Re-review test coverage and quality"
  - label: "Focus: security"             description: "Re-review security and authz"
  - label: "Focus: performance"          description: "Re-review queries, allocations, hot paths"
  - label: "Focus: specific area"        description: "I will name a file, module, or concern"
```

If the user picks any follow-up focus, run Pass 1 + Pass 2 again scoped to that lens (or scoped to the area the user names), emit any new findings as additional `Question`s, and re-issue the "Anything else?" question. Loop until the user picks "No, stage the review". Only then proceed.

After the user picks "No, stage the review", wrap the approved ones in a **single formal review** containing **multiple inline comments** — one comment per finding, each anchored to its own file and line range so every finding is a separately resolvable thread. Workflow:

1. Create a `PENDING` review pinned to the current head SHA.
2. Attach one inline comment per approved inline finding via `/pulls/{pr}/reviews/{review_id}/comments`.
3. Stage any general-scope findings into a prepared review body (do **not** post separately).
4. **Stop. Do not submit.** Submission is always deferred to the user.

Print the PR URL so the user can preview the pending review on GitHub (the pending review is visible to the author in the PR's "Files changed" tab), then ask for the submission event via the **`Question` tool** (clickable options only — never a prose prompt):

```
header:   "Submit review"
question: "Pending review staged at <PR URL/files>. N inline threads, M general items. How should I submit?"
options:
  - label: "Comment"           description: "Post feedback without blocking or approving"
  - label: "Request changes"   description: "Post feedback and block merge"
  - label: "Approve"           description: "Post feedback and approve"
  - label: "Skip"              description: "Leave PENDING for me to submit on GitHub"
  - label: "Delete"            description: "Discard the pending review entirely"
```

Act on the user's selection: `Comment`/`Request changes`/`Approve` → submit with the matching `event`. `Skip` → leave pending, print the PR URL. `Delete` → `DELETE /pulls/{pr}/reviews/{review_id}`.

Use [references/gh-commenting.md](references/gh-commenting.md) for the exact `gh api` calls, including multi-line ranges, suggestion blocks, and how to recover when an anchor no longer maps to the diff.

After the user chooses the submission event (or skips/deletes), print a ledger:
```
Status:  SUBMITTED (COMMENT | REQUEST_CHANGES | APPROVE) | PENDING | DELETED
Review:  https://github.com/.../pull/N#pullrequestreview-...   # when SUBMITTED
PR:      https://github.com/.../pull/N                         # when PENDING
Staged:  N inline threads, M general items (in review body).
Skipped: K rejected, R unanchored (downgraded to general or dropped).
Threads:
  F1  https://github.com/...#discussion_r...
  F2  https://github.com/...#discussion_r...
```

---

## Hard Rules

- Examine **every** changed file. Do not sample.
- Skip findings that duplicate existing review threads.
- Never post to GitHub in SELF mode.
- Never post findings the user rejected in COLLAB mode.
- Never delete, replace, overwrite, or remove existing feedback — including `PENDING` review comments — without explicit user approval through the `Question` tool first. If existing feedback violates these rules, propose Keep / Replace / Edit / Delete as clickable choices.
- **All user decisions in COLLAB mode (per-finding approve/reject/edit and the final submit event) MUST be collected via the harness `Question` tool** with clickable options. Prose prompts like `Action? (a)/(r)/(e)` are forbidden — they require the user to type, which is not allowed.
- **Concise findings only**: `title` ≤ 80 chars, `body` ≤ 3 sentences / ≤ 60 words. No restating the diff, no motivation filler, no "this keeps things consistent" sentences. One finding = one ask.
- **Do not publish severity labels to GitHub**: `required` / `good_to_have` are internal decision metadata only. They may appear in harness questions and local ledgers, but never in inline comments, general review body, suggestion blocks, or submitted review text.
- Inline comments must resolve to a line that exists on the **head** (`RIGHT`) or **base** (`LEFT`) of the diff; otherwise convert to a general PR comment.
- Do not run the project's formatters/linters/tests as part of review unless the user asks — reviewing is read-only on the working tree.
- Do not include praise, summaries, or general commentary anywhere in the output.
