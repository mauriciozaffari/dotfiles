# Detailed

**Key:** `detailed`

Comprehensive with full context. Include acceptance criteria and edge cases.

## When to use

- The default for most tickets. Good when the work will be picked up later or by someone without
  full context.

## Guidance

- Open with a `## Summary` describing the goal.
- Use a `## Requirements` section with clear bullets.
- Add `## Acceptance Criteria` as a checkbox list that defines "done".
- Note relevant edge cases and constraints; do not invent requirements that weren't implied.
- Use headers and bullets to keep it scannable.

## Example

```
## Summary
Implement a login button in the main navigation header.

## Requirements
- Place button in top-right corner of header
- Use primary color styling consistent with design system

## Acceptance Criteria
- [ ] Button is visible on all pages
- [ ] Button redirects to /login page
- [ ] Button is accessible
```
