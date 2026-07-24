# Posting a Review via `gh`

Use this reference when in COLLAB mode after the user has approved findings.

**Posting model:** wrap all approved findings in **one formal pull-request
review**. Each inline finding is staged as its **own comment** (separately
resolvable thread) anchored to its own file and line range. General-scope
findings go in the review's top-level `body` when submitted, not as separate
issue comments. **Submission is deferred to the user** — the skill stages
everything into a `PENDING` review and stops; the user picks the event
(`COMMENT` / `REQUEST_CHANGES` / `APPROVE`), or leaves it pending, or discards it.

> [!IMPORTANT]
> **There is no API to add a comment to an existing pending review.**
> `POST /pulls/{pr}/reviews/{review_id}/comments` **does not exist and returns
> 404.** GitHub only lets you attach inline comments at the moment the review is
> created, via the `comments[]` array on `POST /pulls/{pr}/reviews`. So you build
> the full list of inline comments first, then create the review **once** with
> that array and **no** `event` — which leaves it `PENDING`. To add or change a
> comment afterwards you must delete the pending review and recreate it with the
> complete array.

Flow:

1. Resolve `HEAD_SHA`.
2. Build the `comments[]` array — one object per approved `scope: inline` finding.
3. Create the review in a **single** `POST /pulls/{pr}/reviews` call with
   `{commit_id, comments}` and **no** `event`. This stages a `PENDING` review
   with every inline thread.
4. Stop. Present the PR URL and ask the user for the submission decision.
5. Submit (or skip / delete) according to the user's choice.

## Table of contents

- [Resolve identifiers](#resolve-identifiers)
- [Building JSON without jq](#building-json-without-jq)
- [Comment object shape](#comment-object-shape)
- [Stage the pending review (single call)](#stage-the-pending-review-single-call)
- [Verify the staged threads](#verify-the-staged-threads)
- [Comments with GitHub suggestion blocks](#comments-with-github-suggestion-blocks)
- [General-scope findings](#general-scope-findings)
- [Hand off to the user for submission](#hand-off-to-the-user-for-submission)
- [Submit the review (after user chooses the event)](#submit-the-review-after-user-chooses-the-event)
- [Skip or delete](#skip-or-delete)
- [Re-staging (add / edit a comment)](#re-staging-add--edit-a-comment)
- [Fallbacks and pitfalls](#fallbacks-and-pitfalls)

## Resolve identifiers

```bash
OWNER=<owner>; REPO=<repo>; PR=<number>
HEAD_SHA=$(gh pr view "$PR" -R "$OWNER/$REPO" --json headRefOid --jq .headRefOid)
```

Pin the review to `$HEAD_SHA`. If the PR head moves mid-review, re-fetch
`HEAD_SHA`, re-verify every anchor, and start the review over (a pending review
can be deleted with `DELETE /pulls/{pr}/reviews/{review_id}`).

## Building JSON without jq

`jq` is **not guaranteed to be installed**. Comment bodies contain markdown,
newlines, and fenced suggestion blocks, so build the payload with `python3`
(always present in this project's toolchain) rather than hand-escaping shell
strings. Every example below uses `python3`; if `jq` is available you may use it
instead, but do not assume it.

## Comment object shape

Each element of the `comments[]` array is one inline thread. Strip **all**
internal decision metadata from `body` first — no `required`, `good_to_have`,
`[required]`, `[good_to_have]`, severity headings, finding IDs, or
approve/reject/edit wording. The GitHub-visible body is only the concise request
and an optional suggestion block.

- **Single line:** `{ "path", "line", "side", "body" }`
- **Line range (default for multi-line context):** `{ "path", "start_line", "start_side", "line", "side", "body" }`

Rules:

- `start_line` / `line` are line numbers in the file on the given `side` (not diff-hunk offsets).
- `side=RIGHT` anchors on the PR head (post-change). `side=LEFT` anchors on the base (pre-change).
- `start_line` must be strictly less than `line`. For a single line, omit `start_line` / `start_side`.
- The anchored line must exist in the diff at `HEAD_SHA`; otherwise the whole create call fails (see pitfalls).

## Stage the pending review (single call)

Build the array (one dict per inline finding) and create the review in one POST.
Omitting `event` leaves it `PENDING`.

```bash
python3 - "$HEAD_SHA" <<'PY' > /tmp/review.json
import json, sys

head = sys.argv[1]

comments = [
    # Single-line comment with a suggestion block:
    {
        "path": "spec/services/audit_imports/detail_applier_spec.rb",
        "line": 230,
        "side": "RIGHT",
        "body": (
            "Use a non-subscription row so the test fails on the old guard.\n\n"
            "```suggestion\n"
            "            { 'type' => 'avod', 'channel' => 'Prime' },\n"
            "```\n"
        ),
    },
    # Line-range comment (start_line < line):
    {
        "path": "app/models/user.rb",
        "start_line": 120,
        "start_side": "RIGHT",
        "line": 125,
        "side": "RIGHT",
        "body": "Extract the duplicated normalization into `Email.normalize`.",
    },
]

print(json.dumps({"commit_id": head, "comments": comments}))
PY

REVIEW_ID=$(gh api --method POST \
  "repos/$OWNER/$REPO/pulls/$PR/reviews" \
  --input /tmp/review.json \
  --jq .id)
echo "REVIEW_ID=$REVIEW_ID"
```

The response `state` is `PENDING` and `id` is the review ID. Capture it for
submission and the ledger.

## Verify the staged threads

Confirm each inline comment landed on the intended file before handing off:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID/comments" \
  --jq '.[] | {id, path, html_url}'
```

Capture each comment's `html_url` (the `#discussion_r...` deep link) for the
ledger. In this listing `line` / `side` may read `null` for a pending review —
that is expected and does not mean the anchor failed; the create call would have
errored if an anchor were invalid.

## Comments with GitHub suggestion blocks

Embed a suggestion inside a comment's `body`:

````text
Extract into the existing `Email.normalize` helper to keep normalization in one place.

```suggestion
user.email = Email.normalize(params[:email])
```
````

Suggestions only apply cleanly when the suggestion block matches the anchored
line range exactly (same number of lines). For multi-line suggestions, ensure
`start_line..line` covers precisely the lines the suggestion replaces.

## General-scope findings

Do **not** put general findings in the `comments[]` array — they have no line
anchor. Hold them and render them into the review's submission `body` at submit
time. Use a short, flat list — no praise, no recap, no severity labels:

```text
General:
- Migration lacks a backfill plan for existing rows.
- New `UserPolicy#export?` is not referenced by any controller.
```

Do not include `[required]`, `[good_to_have]`, `required:`, `good_to_have:`, or
finding IDs in the submitted review body. Do **not** post them as separate
`gh pr comment` calls; they belong in the review body so all feedback arrives
atomically.

## Hand off to the user for submission

Once the pending review is staged and verified, **do not submit**. Print the PR
URL and collect the submission event via the harness `Question` tool (clickable
options only — never a prose prompt). The pending review is visible to the PR
author in the "Files changed" tab on GitHub — they can inspect, edit, or add to
it before submitting.

## Submit the review (after user chooses the event)

```bash
EVENT=<COMMENT|REQUEST_CHANGES|APPROVE>   # from the user's choice
REVIEW_BODY=<general-scope findings, or empty string>

python3 -c 'import json,sys; print(json.dumps({"event": sys.argv[1], "body": sys.argv[2]}))' \
  "$EVENT" "$REVIEW_BODY" \
| gh api --method POST \
    "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID/events" \
    --input - --jq .html_url
```

- Pass the exact `event` the user chose. Do not pick an event on the user's behalf.
- `body` holds the general-scope findings (may be an empty string).
- Capture `html_url` for the ledger.

## Skip or delete

- **Skip:** do nothing. The review stays `PENDING` and the user submits from the GitHub UI. Print the PR URL.
- **Delete:** discard the pending review entirely **only when the user
  explicitly selected Delete in the final `Question`**.

```bash
gh api --method DELETE "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID"
```

## Re-staging (add / edit a comment)

Because comments can only be attached at creation time, there is no in-place
edit. To add, remove, or change an inline comment on a review you have not yet
submitted:

1. `DELETE /pulls/{pr}/reviews/{review_id}` to discard the pending review.
2. Rebuild the full `comments[]` array with the change applied.
3. Recreate the review with the single-call flow above.

This is safe only for a pending review **you** created in this run. Never delete
a pending review that may contain another user's edits without explicit approval
(see below).

## Existing pending feedback

Before creating or deleting a pending review, inspect existing reviews/comments
from the current viewer:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" \
  --jq '.[] | {id, user: .user.login, state}'
```

Never remove, overwrite, or replace existing pending feedback without explicit
user approval through the harness `Question` tool. A pending review you created
moments ago in the same staging attempt (empty, or superseded by a re-stage) is
your own artifact and safe to delete; a pre-existing pending review may contain
user edits and is not.

If existing feedback is stale, invalid, duplicated, too verbose, lacks a valid
anchor, or includes internal-only metadata such as `required` / `good_to_have`,
propose one of these actions with clickable options:

- **Keep as-is** — leave the existing feedback untouched.
- **Replace** — use the proposed rewritten concise comment.
- **Edit** — ask the user for a revised version.
- **Delete** — remove the existing feedback.

Only call `DELETE /pulls/{pr}/reviews/{review_id}` after the user chooses that
action. If the PR head moves while a review is pending, do not delete and redo
automatically; ask first because the pending comments may contain user edits.

## Fallbacks and pitfalls

- **404 on `/pulls/{pr}/reviews/{review_id}/comments`** — that endpoint does not
  exist. You cannot add comments to a review after it is created. Stage every
  inline comment in the `comments[]` array of the create call instead.
- **422 Unprocessable Entity on the create call** — one of the comment anchors
  (`path` + `line`/`start_line` + `side`) doesn't map to the diff at `HEAD_SHA`.
  The whole call fails, so no partial review is created. Re-check each anchor
  against the current diff; drop or downgrade the offending finding to general
  (move it to the review body) and recreate.
- `start_line` equal to or greater than `line` is rejected — swap them or collapse to a single line.
- Comments on deleted files or binary files are not allowed. Convert those to general-scope.
- `jq: command not found` — build JSON with `python3` as shown; do not assume `jq` is installed.
- If the PR head moves while the review is pending, ask before deleting or
  replacing existing feedback. Only after the user approves, redo against the
  new `HEAD_SHA`:

  ```bash
  gh api --method DELETE "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID"
  ```

- Fork PRs: posting a review requires the token's identity to have at least
  Triage on the base repo. On a 403, stop and report.
- Never force-push, amend, or push commits to the PR branch. Review is read-only.
- If `gh auth status` fails, stop and report — do not try alternative auth.
