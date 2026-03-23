---
name: fix-rspec
description: Fix RSpec test failures systematically, one file at a time.
---

## Workflow

### 1. If Failures Are Already in Context

Skip discovery and go straight to fixing. Otherwise, run `rspec` to identify failures.

### 2. Fix One File at a Time

For each failing spec file:

1. Read the spec file and the implementation it tests
2. Analyze whether the issue is in the **test** or the **implementation**:
   - Test bug: outdated expectations, wrong setup, missing stubs
   - Implementation bug: actual code defect the test correctly caught
   - Both: test needs updating AND implementation has a bug
3. Make the fix
4. Validate with the specific line number:

```bash
rspec spec/<path>/<file>_spec.rb:<line_number>
```

### 3. After All Individual Fixes

Run only previously failed specs:

```bash
rspec --only-failures
```

If any fail, repeat from step 2.

### 4. Full Suite Verification

Only when `--only-failures` passes, run the full suite:

```bash
rspec
```

If any spec fails, start over from step 2 with the new failures.

## Analysis Guidelines

Before fixing, determine the root cause:

**Signs the test is wrong:**
- Test doesn't match current requirements or feature behavior
- Outdated mocks/stubs that no longer reflect dependencies
- Brittle assertions on implementation details
- Test setup doesn't reflect real usage

**Signs the implementation is wrong:**
- Test matches documented/expected behavior
- Other tests rely on the same behavior working
- Recent changes broke previously working functionality
- Edge case not handled

**When uncertain:**
- Check git history for recent changes to both files
- Look for related tests that pass/fail
- Read any associated documentation or comments
- Ask if the expected behavior is unclear

## Configuration

Ensure `spec/spec_helper.rb` has:

```ruby
RSpec.configure do |config|
  config.example_status_persistence_file_path = "spec/examples.txt"
end
```

This enables `--only-failures` to work.
