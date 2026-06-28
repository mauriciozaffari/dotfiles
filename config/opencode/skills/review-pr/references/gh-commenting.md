# Posting a Review via `gh`

Use this reference when in COLLAB mode after the user has approved findings.

**Posting model:** wrap all approved findings in **one formal pull-request review**. Each finding is attached to the review as its **own inline comment** (separately resolvable thread) anchored to its own file and line range. General-scope findings go in the review's top-level `body` when submitted, not as separate issue comments. **Submission is deferred to the user** — the skill stages everything into a `PENDING` review and stops; the user picks the event (`COMMENT` / `REQUEST_CHANGES` / `APPROVE`), or leaves it pending, or discards it.

Flow:

1. Create a `PENDING` review pinned to the current head SHA.
2. For each approved finding with `scope: inline`, post one review comment under that review.
3. Stop. Present the PR URL and ask the user for the submission decision.
4. Submit (or skip / delete) according to the user's choice.

## Table of contents

- [Resolve identifiers](#resolve-identifiers)
- [Create a pending review](#create-a-pending-review)
- [Add an inline comment to the review (line range)](#add-an-inline-comment-to-the-review-line-range)
- [Add an inline comment to the review (single line)](#add-an-inline-comment-to-the-review-single-line)
- [Comments with GitHub suggestion blocks](#comments-with-github-suggestion-blocks)
- [General-scope findings](#general-scope-findings)
- [Hand off to the user for submission](#hand-off-to-the-user-for-submission)
- [Submit the review (after user chooses the event)](#submit-the-review-after-user-chooses-the-event)
- [Skip or delete](#skip-or-delete)
- [Fallbacks and pitfalls](#fallbacks-and-pitfalls)

## Resolve identifiers

```bash
OWNER=<owner>; REPO=<repo>; PR=<number>
HEAD_SHA=$(gh pr view "$PR" -R "$OWNER/$REPO" --json headRefOid --jq .headRefOid)
```

Pin the review and every inline comment to `$HEAD_SHA`. If the PR head moves mid-review, re-fetch `HEAD_SHA`, re-verify every anchor, and start the review over (a pending review can be deleted with `DELETE /pulls/{pr}/reviews/{review_id}`).

## Create a pending review

```bash
REVIEW_ID=$(gh api \
  --method POST \
  "repos/$OWNER/$REPO/pulls/$PR/reviews" \
  -f commit_id="$HEAD_SHA" \
  --jq .id)
```

Omitting `event` leaves the review in `PENDING` state so comments can be attached before submission.

## Add an inline comment to the review (line range)

This is the default — most findings span more than one line of context. Each call creates a new, independently-resolvable thread under the pending review.

Before assigning `$BODY`, strip all internal decision metadata. The GitHub-visible body must not include `required`, `good_to_have`, `[required]`, `[good_to_have]`, severity headings, finding IDs used only by the harness, or approve/reject/edit wording.

```bash
jq -n \
  --arg path      "app/models/user.rb" \
  --argjson start_line 120 \
  --arg start_side "RIGHT" \
  --argjson line      125 \
  --arg side      "RIGHT" \
  --arg body      "$BODY" \
  '{path:$path, start_line:$start_line, start_side:$start_side, line:$line, side:$side, body:$body}' \
| gh api --method POST \
    "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID/comments" \
    --input -
```

- `start_line` / `line` are line numbers in the file on the given `side` (not diff-hunk offsets).
- `side=RIGHT` anchors on the PR head (post-change). `LEFT` anchors on the base (pre-change).
- `start_line` must be strictly less than `line`. For a single line, omit `start_line`/`start_side`.
- The response contains `html_url` (deep link to the thread) and `id`. Capture both for the ledger.

## Add an inline comment to the review (single line)

Before assigning `$BODY`, strip all internal decision metadata. The GitHub-visible body must be only the concise request and optional suggestion block.

```bash
jq -n \
  --arg path   "app/models/user.rb" \
  --argjson line 123 \
  --arg side   "RIGHT" \
  --arg body   "$BODY" \
  '{path:$path, line:$line, side:$side, body:$body}' \
| gh api --method POST \
    "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID/comments" \
    --input -
```

## Comments with GitHub suggestion blocks

Embed a suggestion inside `$BODY`:

````text
Extract into the existing `Email.normalize` helper to keep normalization in one place.

```suggestion
user.email = Email.normalize(params[:email])
```
````

Suggestions only apply cleanly when the suggestion block matches the anchored line range exactly (same number of lines). For multi-line suggestions, ensure `start_line..line` covers precisely the lines the suggestion replaces.

## General-scope findings

Render all `scope: general` findings into the review's submission `body`. Use a short, flat list — no praise, no recap, no severity labels:

```text
General:
- Migration lacks a backfill plan for existing rows.
- New `UserPolicy#export?` is not referenced by any controller.
```

Do not include `[required]`, `[good_to_have]`, `required:`, `good_to_have:`, or finding IDs in the submitted review body.

Do **not** post them as separate `gh pr comment` calls; they belong in the review body so all feedback arrives atomically.

## Hand off to the user for submission

Once all inline comments are attached, **do not submit**. Print the PR URL and prompt the user:

```text
Pending review staged: https://github.com/$OWNER/$REPO/pull/$PR/files
Choose submission event: (c)COMMENT / (r)REQUEST_CHANGES / (a)APPROVE / (s)SKIP (leave pending) / (d)DELETE
```

The pending review is visible to the PR author in the "Files changed" tab on GitHub — they can inspect, edit, or add to it before submitting.

## Submit the review (after user chooses the event)

```bash
EVENT=<COMMENT|REQUEST_CHANGES|APPROVE>   # from the user's choice
REVIEW_URL=$(jq -n --arg event "$EVENT" --arg body "$REVIEW_BODY" \
  '{event:$event, body:$body}' \
| gh api --method POST \
    "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID/events" \
    --input - --jq .html_url)
```

- Pass the exact `event` the user chose. Do not pick an event on the user's behalf.
- `body` holds the general-scope findings (may be empty string).
- Capture `html_url` for the ledger.

## Skip or delete

- **Skip** (`s`): do nothing. The review remains `PENDING` and the user will submit from the GitHub UI. Print the PR URL.
- **Delete** (`d`): discard the pending review entirely **only when the user explicitly selected Delete in the final `Question`**.

```bash
gh api --method DELETE "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID"
```

## Existing pending feedback

Before creating or deleting a pending review, inspect existing reviews/comments from the current viewer. Never remove, overwrite, or replace existing pending feedback without explicit user approval through the harness `Question` tool.

If existing feedback is stale, invalid, duplicated, too verbose, lacks a valid anchor, or includes internal-only metadata such as `required` / `good_to_have`, propose one of these actions with clickable options:

- **Keep as-is** — leave the existing feedback untouched.
- **Replace** — use the proposed rewritten concise comment.
- **Edit** — ask the user for a revised version.
- **Delete** — remove the existing feedback.

Only call `DELETE /pulls/{pr}/reviews/{review_id}` or update/delete review comments after the user chooses that action. If the PR head moves while a review is pending, do not delete and redo automatically; ask first because the pending comments may contain user edits.

## Fallbacks and pitfalls

- `422 Unprocessable Entity` when adding a review comment means the `path` + `line`/`start_line` + `side` doesn't map to the diff at `HEAD_SHA`. Re-check against the current diff; if it still won't anchor, downgrade the finding to general (add it to the review body) and record the downgrade in the ledger.
- `start_line` equal to or greater than `line` is rejected — swap them or collapse to single-line.
- Comments on deleted files or binary files are not allowed. Convert those to general-scope.
- If the PR head moves while the review is pending, ask before deleting or replacing existing feedback. Only after the user approves deletion/replacement, redo against the new `HEAD_SHA`:

  ```bash
  gh api --method DELETE "repos/$OWNER/$REPO/pulls/$PR/reviews/$REVIEW_ID"
  ```

- Fork PRs: posting a review requires the token's identity to have at least Triage on the base repo. On a 403, stop and report.
- Never force-push, amend, or push commits to the PR branch. Review is read-only.
- If `gh auth status` fails, stop and report — do not try alternative auth.
