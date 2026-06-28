# Bug Report

**Key:** `bug_report`

Structured bug report with steps to reproduce and expected behavior.

## When to use

- Something is broken. The request describes a defect, not new functionality.

## Guidance

- Use a symptom-focused summary/title.
- Include these sections: `## Bug Description`, `## Steps to Reproduce` (numbered),
  `## Expected Behavior`, `## Actual Behavior`.
- Add environment details (device, browser, OS, version) when relevant.
- If repro steps are missing, ask the user — do not guess them.

## Example

```
## Bug Description
Login button is not visible on mobile devices.

## Steps to Reproduce
1. Open the site on a mobile device
2. Navigate to any page
3. Look for login button in header

## Expected Behavior
Login button should be visible in mobile header.

## Actual Behavior
Login button is hidden/not rendered on mobile.
```
