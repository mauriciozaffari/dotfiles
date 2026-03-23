---
name: test-coverage
description: Find and fix uncovered lines and branches from lcov coverage reports.
---

## Finding the LCOV File

**Use the Glob tool to search for lcov files:**

```
pattern: "**/lcov.info"
```

Or search for any lcov files:

```
pattern: "**/*.lcov"
```

Common paths:
- `coverage/lcov.info` (Jest, Istanbul, NYC)
- `public/coverage/lcov.info` (SimpleCov with custom path)
- `coverage/lcov/project.lcov`

If no lcov file exists, coverage may not be configured for the project.

## Parsing LCOV Format

**Use Grep tool to extract uncovered code from lcov files.**

LCOV format structure:
- `SF:<filepath>` - Source file path
- `DA:<line>,<hits>` - Line coverage (DA:10,0 means line 10 was not executed)
- `BRDA:<line>,<block>,<branch>,<hits>` - Branch coverage (hits can be 0, -, or a number)
- `end_of_record` - End of file record

### Finding Uncovered Lines

Use Grep to find lines with zero hits:

```
pattern: "^DA:\d+,0$"
path: <lcov_file>
output_mode: "content"
```

This finds lines like `DA:42,0` which means line 42 was not covered.

### Finding Uncovered Branches

Use Grep to find branches with zero or no hits:

```
pattern: "^BRDA:\d+,\d+,\d+,(-|0)$"
path: <lcov_file>
output_mode: "content"
```

This finds lines like `BRDA:59,0,23,-` or `BRDA:70,0,27,0` which are uncovered branches.

### Filtering by File

To find uncovered code in a specific file, use two Grep calls:

1. Find the file section:
```
pattern: "^SF:.*<filename>"
path: <lcov_file>
-A: 100  # Show next 100 lines after match
output_mode: "content"
```

2. Then grep within those results for uncovered lines/branches

### Understanding Branch Numbers

BRDA format: `BRDA:line,block,branch,hits`
- `line`: The source code line number
- `block`: The block ID (for multiple branches on same line)
- `branch`: The branch ID (0 for first branch, 1 for second, etc.)
- `hits`: Number of times taken (0, -, or a positive number)

## Fixing Uncovered Branches

Branches are typically:
1. **If/else branches** - Need tests for both true and false paths
2. **Switch/case branches** - Need tests for each case and default
3. **Guard clauses** - Need tests that trigger early returns
4. **Ternary operators** - Need tests for both outcomes
5. **&& / || short-circuits** - Need tests for both evaluation paths

## Coverage Skip Guidelines

**NEVER use coverage skip markers** like `:nocov:`, `# pragma: no cover`, `/* istanbul ignore */`, or any similar mechanism.

If code or branches cannot be covered:

1. **Unreachable code should be removed** - If code cannot be executed, it's dead code and should be deleted
2. **Unreachable branches should be removed** - If a branch cannot be triggered, simplify the logic to remove it
3. **Question the necessity** - If you can't test it, do you really need it?
4. **Fix the code, not the coverage** - Don't hide problems with skip markers

Valid coverage skips are extremely rare. If you think you need one, you probably need to refactor instead.

## Process

1. **Run tests with coverage** - Use the project's test command with coverage enabled
2. **Find the lcov file** - Use Glob tool with pattern `**/lcov.info` or `**/*.lcov`
3. **Find uncovered code** - Use Grep tool to search for uncovered lines (`DA:.*,0`) and branches (`BRDA:.*,(-|0)`)
4. **Read the source file** - Use Read tool to understand the code at the uncovered line numbers
5. **Write a test** - Create or update test files to cover the missing paths
6. **Re-run tests** - Verify coverage improved
7. **Repeat** - Continue until target coverage reached

### Example Workflow

```
# Step 1: Find lcov file
Glob: pattern="**/lcov.info"

# Step 2: Find uncovered branches in a specific file
Grep: pattern="^SF:.*entry_charge_handling", path="coverage/lcov.info", -A=50

# Step 3: Extract branch information
Grep: pattern="^BRDA:\d+,\d+,\d+,(-|0)$", path="coverage/lcov.info", output_mode="content"

# Step 4: Read the source file at uncovered line numbers
Read: file_path="app/controllers/concerns/entry_charge_handling.rb", offset=8, limit=10

# Step 5: Write test to cover the missing branch
# Step 6: Re-run tests and verify
```
