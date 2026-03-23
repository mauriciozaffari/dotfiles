---
name: code-review
description: Review code changes and remove AI-generated patterns.
---

## What to Look For

### Excessive Comments
AI tends to over-comment. Remove comments that:
- State the obvious (e.g., **// increment counter** above **counter++**)
- Repeat the function/variable name

### Gratuitous Defensive Checks
Remove defensive code that doesn't match the codebase style:
- Null checks on values already validated upstream
- Type checks on typed parameters
- Exception treatment blocks in trusted codepaths
