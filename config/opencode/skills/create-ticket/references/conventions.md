# Project Convention Discovery (Create Ticket)

Conventions are **project-specific** and must be discovered from the project being worked on —
never assumed from another project. This guide defines what the `create-ticket` workflow needs to
file a Jira ticket in the right place, and how to resolve each item for the current repository.

## Resolution Order

Resolve each convention using the first source that provides it:

1. **`CONVENTIONS.md`** at the project root — if present and complete, use it directly and skip
   scanning. If present but missing some items, use what it has and scan only for the gaps.
2. **`AGENTS.md` / `CLAUDE.md`** (and any files they reference) — agent-facing docs often name the
   Jira site and project keys.
3. **Project scan** — derive remaining conventions from the sources in the table below. Delegate to
   an `explore` sub-agent when multiple sources need checking.

If a required item cannot be discovered (especially `cloudId` or project key), **ask the user**
rather than guessing.

## Conventions Needed

| Convention | What to determine | Where to look |
|---|---|---|
| **Jira site / `cloudId`** | The `{site}.atlassian.net` host passed as `cloudId` | `CONVENTIONS.md`, `AGENTS.md`/`CLAUDE.md`, `.env`/`.env.example`, CI config, ask the user. If the host is unknown, `getAccessibleAtlassianResources` lists accessible sites. |
| **Project key** | Jira project key (e.g. `PREFIX`, `ENG`) | Existing ticket prefixes in branch names / `git log`, agent docs, `getVisibleJiraProjects` |
| **Default issue type** | `Task` / `Bug` / `Story` / etc. | Infer from the request; confirm at draft time. Use `getJiraProjectIssueTypesMetadata` if the valid types are unclear. |
| **Required fields** | Any required custom fields for the issue type | `getJiraIssueTypeMetaWithFields` if a create call fails on a missing field |

## Discovery Notes

- **cloudId**: Prefer passing the site host (e.g. `mysite.atlassian.net`) directly as `cloudId`.
  Only call `getAccessibleAtlassianResources` if that fails or the host is unknown.
- **Project key**: The fastest signal is existing ticket prefixes in `git log`/branch names
  (e.g. `PREFIX-123-...`). Otherwise `getVisibleJiraProjects` enumerates projects the user can
  create in.
- **Issue type**: Match the request — a defect → `Bug`, a feature → `Story`/`Task`. When unsure,
  default to `Task` and confirm in the draft step.
- **Assignee**: If the user names an assignee, resolve their account ID with `lookupJiraAccountId`
  before creating, and pass it as the top-level `assignee_account_id` param.

## CONVENTIONS.md Shape (when saving)

If the user wants to persist discovered ticketing conventions, add a section covering: Jira Site
(`cloudId`), Project Key(s), Default Issue Type, and any required custom fields. Reference it from
`AGENTS.md` / `CLAUDE.md`. Only write these files with explicit user consent.
