# Guidelines

## Communication Style

- When writing something intended for human consumption, (comment, commit message, reply to prompt) use as few words as possible. Pick every word meticulously to reduce the volume to a strict minimum. Be down to the point. Less is more.
- Avoid superlatives and praise. Stop telling me I am absolutely right. Give me the cold hard truth.

## Philosophy

### Core Beliefs

- **Incremental progress over big bangs** - Small changes that compile and pass tests
- **Learning from existing code** - Study and plan before implementing
- **Pragmatic over dogmatic** - Adapt to project reality
- **Clear intent over clever code** - Be boring and obvious

### Simplicity

- **Single responsibility** per function/class
- **Avoid premature abstractions**
- **No clever tricks** - choose the boring solution
- If you need to explain it, it's too complex
- **DRY (Don't Repeat Yourself)** - Extract common logic

## Technical Standards

### Architecture Principles

- **Explicit over implicit** - Clear data flow and dependencies
- **Test-driven when possible** - Never disable tests, fix them

### Error Handling

- **Fail fast** with descriptive messages
- **Include context** for debugging
- **Handle errors** at appropriate level
- **Never** silently swallow exceptions

## Project Integration

### Learn the Codebase

- Find similar features/components
- Identify common patterns and conventions
- Use same libraries/utilities when possible
- Follow existing test patterns

### Tooling

- Use project's existing build system
- Use project's existing test framework
- Use project's formatter/linter settings
- Don't introduce new tools without strong justification

### Leveraging Skills

- **Check available skills first** - Use `/fix-rspec`, `/fix-jest`, `/fix-vitest`, `/test-coverage` for test-related tasks
- **Skills are specialized tools** - They follow best practices and project patterns
- **Don't reinvent** - If a skill exists for the task, use it
- **Skills handle complexity** - Let specialized agents handle iteration and validation

### Code Style

- Follow existing conventions in the project
- Refer to linter configurations
- Text files should always end with an empty line

### Comments and Documentation

- **Comments explain *why*, never *what*** - delete a comment that restates the code
- **Keep comments short** - if the explanation runs past ~2 lines, it isn't a comment anymore
- **Long-form explanation belongs in `docs/`** - rationale, trade-offs, background, step-by-step
  behaviour, and migration/rollout notes go in the project's markdown docs
- **Link, don't inline** - leave a one-line pointer in the code (`# See docs/DATA_MIGRATIONS.md`)
  instead of pasting the narrative above the implementation
- **Don't grow comment blocks across edits** - when you find yourself appending another paragraph
  to an existing comment, move the whole thing to a doc and replace it with the pointer

## Important Reminders

**NEVER**:

- Use `--no-verify` to bypass commit hooks
- Disable tests instead of fixing them
- Disable linting rules without trying to fix it first
- Make assumptions - verify with existing code
- Include Generated with ... in commit messages

**ALWAYS**:

- Update plan documentation as you go
- Learn from existing implementations
- Stop after 3 failed attempts and reassess
