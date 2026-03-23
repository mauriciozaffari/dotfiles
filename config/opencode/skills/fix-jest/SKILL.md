---
name: fix-jest
description: Fix Jest test failures systematically, one file at a time.
---

## Workflow

### 1. If Failures Are Already in Context

Skip discovery and go straight to fixing. Otherwise, run tests to identify failures.

### 2. Fix One File at a Time

For each failing test file:

1. Read the test file and the implementation it tests
2. Analyze whether the issue is in the **test** or the **implementation**:
   - Test bug: outdated expectations, wrong setup, missing mocks
   - Implementation bug: actual code defect the test correctly caught
   - Both: test needs updating AND implementation has a bug
3. Make the fix
4. Validate with the specific file and test name:

```bash
npx jest src/path/file.test.ts -t "test name pattern"
```

Or run just the file:
```bash
npx jest src/path/file.test.ts
```

### 3. After All Individual Fixes

Run only previously failed tests:

```bash
npx jest --onlyFailures
```

If any fail, repeat from step 2.

### 4. Full Suite Verification

Only when failed tests pass, run the full suite:

```bash
npx jest
```

If any test fails, start over from step 2 with the new failures.

## Analysis Guidelines

Before fixing, determine the root cause:

**Signs the test is wrong:**
- Test doesn't match current requirements or feature behavior
- Outdated mocks that no longer reflect dependencies
- Brittle assertions on implementation details (e.g., exact error messages)
- Snapshot outdated vs implementation change
- Async timing issues or missing `await`

**Signs the implementation is wrong:**
- Test matches documented/expected behavior
- Other tests rely on the same behavior working
- Recent changes broke previously working functionality
- Edge case not handled
- Type errors caught at runtime

**When uncertain:**
- Check git history for recent changes to both files
- Look for related tests that pass/fail
- Read any associated documentation or comments
- Ask if the expected behavior is unclear

## Configuration

Ensure `jest.config.js` has caching enabled for `--onlyFailures`:

```javascript
module.exports = {
  cache: true,
  cacheDirectory: 'node_modules/.cache/jest',
};
```

## Common Patterns

**Update snapshots** (only after confirming the change is correct):
```bash
npx jest -u src/path/file.test.ts
```

**Run with verbose output:**
```bash
npx jest --verbose src/path/file.test.ts
```

**Debug a single test:**
```bash
node --inspect-brk node_modules/.bin/jest --runInBand src/path/file.test.ts
```

**Watch mode for iterative fixing:**
```bash
npx jest --watch src/path/file.test.ts
```
