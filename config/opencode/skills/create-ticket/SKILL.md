---
name: create-ticket
description: >-
  End-to-end Jira ticket creation harness. Gathers a summary and rough
  description, enhances the description in a chosen writing style, confirms with
  the user, and creates the ticket via the Atlassian MCP. Use when the user says
  "create a ticket", "open a Jira ticket", "file a bug", "draft a ticket",
  "new issue for ...", or otherwise asks to create work in Jira. Supports an
  optional writing style passed up front (e.g. "create a ticket in bug_report
  style"); when no style is given, the harness asks which style to use.
---

# Create Ticket

Orchestrate the full idea-to-Jira-ticket workflow: discover conventions → pick writing style →
gather inputs → enhance description → confirm → create ticket via Atlassian MCP.

This skill is **repo-agnostic**. All project-specific details (Jira site/`cloudId`, project key,
default issue type) are **discovered from the current project**, not assumed. Read
[references/conventions.md](references/conventions.md) — it defines what conventions are needed and
how to resolve them — and complete Step 0 before creating anything.

The description-enhancement step mirrors how Develoz Agent enhances ticket descriptions: keep the
original intent, improve clarity and structure, fill obvious gaps but **never invent new
requirements**, and match the selected writing style.

## Workflow

0. **Discover conventions** for the current project (Jira site/`cloudId`, project key, issue type)
1. **Resolve writing style** — from the user's invocation, or ask with the question tool
2. **Gather inputs** — summary + rough description (ask if missing)
3. **Enhance description** in the chosen style
4. **Present draft** to the user, gather feedback, iterate
5. **Create ticket** via the Atlassian MCP
6. **Report** the created ticket key and URL

---

## Step 0: Discover Project Conventions

Resolve the conventions defined in [references/conventions.md](references/conventions.md) for the
current repository, using this order:

1. **`CONVENTIONS.md`** at the project root — if present and complete, use it directly and skip the
   scan. If present but incomplete, use what it has and scan only for the missing items.
2. **`AGENTS.md` / `CLAUDE.md`** (and files they reference) for Jira site/project rules.
3. **Scan the project** — existing ticket prefixes in branch names / `git log`, `.env(.example)`,
   CI configs, or agent docs. Delegate a broad scan to an `explore` sub-agent when several sources
   must be checked.

Key things to determine:
- **Jira site / `cloudId`** — the `{site}.atlassian.net` host (pass as `cloudId`).
- **Project key** — e.g. `PREFIX`, `ENG`, derived from existing ticket prefixes or agent docs.
- **Default issue type** — `Task`, `Bug`, `Story`. Infer from the request; otherwise default to
  `Task` and confirm at draft time.

If a required convention cannot be discovered (especially the `cloudId` or project key), **ask the
user** rather than guessing.

---

## Step 1: Resolve Writing Style

Writing styles live in [styles/](styles/) — one file per style, each with its name, description, and
a worked example. The available styles are:

- **`concise`** — short and to the point; essential requirements only
- **`detailed`** — comprehensive, with acceptance criteria and edge cases
- **`user_story`** — user-story format with acceptance criteria
- **`technical`** — developer-focused with implementation hints and file references
- **`bug_report`** — structured bug report with repro steps and expected/actual behavior

**Resolution order:**

1. **Explicit in the request** — if the user named a style (e.g. "create a ticket in `bug_report`
   style", "make it a user story"), use it. Map natural phrasing to the closest style key.
2. **Strong signal from content** — if the request is clearly a bug ("X is broken, steps: ..."),
   you may propose `bug_report` — but still confirm via the question tool unless the user was
   explicit.
3. **Otherwise ASK** — use the question tool to ask which style to use. Present the five styles as
   options with their one-line descriptions:

```
question(
  header="Writing style",
  question="Which writing style should I use for this ticket?",
  options=[
    { label: "Detailed (Recommended)", description: "Comprehensive with acceptance criteria and edge cases" },
    { label: "Concise",     description: "Short and to the point; essential requirements only" },
    { label: "User Story",  description: "User-story format with acceptance criteria" },
    { label: "Technical",   description: "Developer-focused with implementation hints and file references" },
    { label: "Bug Report",  description: "Repro steps, expected vs actual behavior" }
  ]
)
```

Once resolved, **read the matching file in [styles/](styles/)** and follow its guidance and example
exactly when enhancing.

## Step 2: Gather Inputs

A ticket needs at minimum a **summary** (title) and a **description** (raw idea). Extract whatever
the user already provided.

If the summary or description is missing or too thin to enhance meaningfully, **ask the user** for:
- A one-line summary / title
- The core requirement or problem (a few sentences is enough — you will enhance it)
- For `bug_report` style: steps to reproduce, expected vs. actual behavior, environment
- Optionally: priority, labels, components, parent epic, assignee, an example ticket to mimic

Do not invent missing requirements — ask instead.

## Step 3: Enhance the Description

Enhance the raw description into the chosen style. Apply the same rules Develoz Agent uses for
description enhancement:

1. Keep the original requirements and intent intact.
2. Improve clarity and organization.
3. Add structure with headers and bullet points where appropriate.
4. Fill in obvious gaps but **do NOT invent new requirements**.
5. Match the requested writing style (follow the example in the style file).
6. If the user supplied an example ticket, follow its structure, tone, and format closely.

Also refine the **summary** into a clear, concise title consistent with the style (e.g. for
`bug_report`, a symptom-focused title).

## Step 4: Present Draft and Gather Feedback

Show the user the full draft before creating anything:

```
## Draft Ticket

**Project**: {project-key}  |  **Type**: {issue_type}  |  **Style**: {style}
{**Priority / Labels / Components / Parent**: ... — only if set}

**Summary**: {enhanced summary}

**Description**:
{enhanced description in the chosen style}
```

Wait for confirmation. Accept edits to the summary, description, style, or any field. If the user
changes the style, re-read that style file and re-enhance. Do NOT create the ticket until the user
explicitly approves.

## Step 5: Create the Ticket

Once approved, create the ticket via the Atlassian MCP, using the `cloudId` and project key from
Step 0:

```
createJiraIssue(
  cloudId: "{discovered-site}.atlassian.net",
  projectKey: "{PROJECT-KEY}",
  issueTypeName: "{Task|Bug|Story|...}",
  summary: "{enhanced summary}",
  description: "{enhanced description}",
  contentFormat: "markdown",
  additional_fields: { ... }   // ONLY for fields with no dedicated param:
                               // priority, labels, components, fixVersions, custom fields
)
```

Field placement notes:
- `summary`, `description`, `issueTypeName`, `projectKey` are top-level params.
- `assignee_account_id` is a top-level param — resolve it first with `lookupJiraAccountId` if the
  user named an assignee.
- `parent` is a top-level param (for sub-tasks / epic parent).
- Everything else (priority, labels, components, fix versions, custom fields) goes inside
  `additional_fields`, e.g. `{ "priority": { "name": "High" }, "labels": ["frontend"] }`.

If creation fails due to a field (e.g. required custom field, invalid issue type), read the error,
adjust, and retry — ask the user when the fix is ambiguous.

## Step 6: Report

Provide the user with:
- The created **ticket key** and its **URL** (`https://{site}.atlassian.net/browse/{KEY}`)
- A one-line summary of what was created (type, style, key fields)
- Any follow-ups (e.g. "assignee not set — no match found", "added to epic PREFIX-100")
