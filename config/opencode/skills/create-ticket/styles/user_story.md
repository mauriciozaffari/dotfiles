# User Story

**Key:** `user_story`

Written in user story format with clear acceptance criteria.

## When to use

- Product/feature work framed around user value, especially on agile teams using stories.

## Guidance

- Open with the canonical form: "As a {role}, I want {capability}, so that {benefit}."
- Follow with `## Acceptance Criteria` using Given/When/Then phrasing.
- Keep criteria testable and outcome-focused, not implementation detail.
- Preserve the original intent; do not add scope the user didn't ask for.

## Example

```
As a visitor,
I want to see a login button in the header,
So that I can easily access my account.

## Acceptance Criteria
- Given I am on any page
- When I look at the header
- Then I see a clearly visible login button

- Given I click the login button
- Then I am redirected to the login page
```
