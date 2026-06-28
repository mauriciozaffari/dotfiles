# Technical

**Key:** `technical`

Developer-focused with implementation hints and technical details.

## When to use

- The implementer benefits from concrete pointers: components, files, APIs, libraries.

## Guidance

- State the change in terms of the code/components involved.
- Add a `## Technical Details` section with specific implementation hints.
- Add a `## Files to modify` (or create) list when the touch points are known.
- Reference real symbols, paths, and library APIs where possible.
- Hints are guidance, not gospel — don't fabricate file paths you can't justify.

## Example

```
Implement login button in `Header` component.

## Technical Details
- Add `LoginButton` component to `src/components/Header`
- Use `Button` from UI library with `variant="primary"`
- Route to `/login` using React Router `Link`

## Files to modify
- src/components/Header/index.tsx
- src/components/Header/styles.css
```
