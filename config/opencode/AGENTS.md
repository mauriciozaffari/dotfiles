# Development Guidelines

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
- **DRY (Don't Repeat Yourself)** - Extract common logic, but only after the third use
- **Duplication is better than the wrong abstraction** - Wait for patterns to emerge

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

## Important Reminders

**NEVER**:
- Use `--no-verify` to bypass commit hooks
- Disable tests instead of fixing them
- Make assumptions - verify with existing code
- Never include Generated with Claude Code in commit messages

**ALWAYS**:
- Update plan documentation as you go
- Learn from existing implementations
- Stop after 3 failed attempts and reassess