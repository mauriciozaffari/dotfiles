# Review Checklist

Walk this list for **each** changed file. Only emit findings with a concrete anchor and a clear fix.

## Table of contents

- [Goal alignment](#goal-alignment)
- [Correctness](#correctness)
- [Consistency and DRY](#consistency-and-dry)
- [Implementation shape: DRY / KISS / SOLID](#implementation-shape-dry--kiss--solid)
- [Edge cases](#edge-cases)
- [Security](#security)
- [Performance](#performance)
- [API and data contracts](#api-and-data-contracts)
- [Tests](#tests)
- [Submodules](#submodules)
- [Classification guide](#classification-guide)

## Goal alignment

- The PR delivers the core outcome its ticket / description set out to produce.
- Judge the *goal*, not a literal ticket checklist — a change can succeed without implementing every over-specified or stale ticket bullet.
- The implementation solves the problem that was asked, not an adjacent or different one.
- Anything the ticket treated as essential is present, or its absence is justified (descoped / follow-up).
- No substantial scope drift — unrelated changes belong in their own PR.
- Ticket reference resolved from the branch and title first; body references may point at *related* tickets, not this PR's goal.

## Correctness

- Logic matches the intent stated in the PR description and any linked ticket.
- No off-by-one, wrong operator, inverted boolean, swapped arguments.
- Error paths return/raise correctly; no silently swallowed exceptions (`rescue => e; end`, empty `catch {}`).
- Null/undefined/nil handling at every boundary.
- Concurrency: shared state guarded; no TOCTOU; idempotent where retried.
- Time handling: timezone-aware, no `Time.now` where `Time.current` (or UTC) is required; no naive date comparisons across zones.
- Floating point and money: no float math on currency; use decimals/integers.

## Consistency and DRY

- New helpers duplicate existing ones — search the repo for similar names, signatures, or behavior before accepting the new code.
- Naming matches neighbors (snake_case vs camelCase, `fetch_*`/`find_*`, service/job/component suffixes).
- File placement matches layer conventions (controllers, services, policies, presenters, hooks, stores, etc.).
- Error handling, logging, and i18n follow the patterns used by sibling files.
- Public method ordering, visibility modifiers, and documentation match the local style.
- Imports/requires are organized like the rest of the file/module.

## Implementation shape: DRY / KISS / SOLID

Challenge the design, not just the bugs. Every shape finding must reference concrete alternatives in the repo, not abstract principles.

### DRY (duplication of knowledge, not just code)

- Grep the repo for similar function names, signatures, constants, regexes, SQL fragments, error messages, and i18n keys before accepting new ones.
- Two code paths that must change together when a requirement changes are duplicated — even if the code looks different.
- Magic values (limits, timeouts, field lengths) duplicated across files should live in one place.
- Test fixtures / factories duplicated from existing ones.
- Near-duplicates (copy-paste-tweak) are worse than exact duplicates — they hide the divergence.

### KISS (remove what isn't pulling weight)

- Premature abstractions: interfaces/base classes with one implementation, strategy patterns with one strategy, factories that construct one thing.
- Config knobs, flags, or parameters with a single call site value — inline the value.
- Indirection layers that exist "in case we need to swap X later" when there's no concrete plan.
- Generic helpers written for a single caller — inline them; extract when the second caller appears.
- Over-engineered error taxonomies (many new exception classes, each raised once).
- Clever one-liners that require a comment to understand — split into named steps.
- Wrappers around stdlib / framework calls that add nothing.

### SOLID

- **Single responsibility** — a class/module/function that does two things shows up as:
  - A name that's a conjunction ("FetchAndProcess", "ValidatorAndSerializer", "Manager", "Handler", "Service" with unclear scope).
  - Multiple reasons the file would need to change (e.g. changes to the DB schema *and* changes to the email template).
  - Tests that have to stub two unrelated collaborators to exercise one behavior.
- **Open/closed** — new code that branches on a type/role enum with `case`/`if` chains, instead of dispatching polymorphically, forces every future type to edit this file. Flag when a new variant would require touching the same switch in multiple places.
- **Liskov** — subclasses or implementations that:
  - Raise from methods the parent/interface doesn't document as raising.
  - Require additional setup before the parent's contract is valid.
  - Ignore or no-op methods the parent defines.
- **Interface segregation** — public methods on a new module that no caller uses (dead API surface). Abstract base classes that force implementers to stub methods they don't need.
- **Dependency inversion** — high-level logic (domain services, business rules) reaching directly into:
  - Global state: `Time.now`, `Date.today`, `SecureRandom` without injection where a clock/id generator abstraction exists.
  - Infrastructure: raw `Net::HTTP`, `Redis.current`, `File.open` where a wrapper exists.
  - `ENV[...]` reads outside config loaders.

### Shape-finding quality bar

- Name the specific alternative: "collapse `FooHandler` + `FooRunner` into `Foo.call`" — not "this violates SRP".
- Prove reuse when citing DRY: "same normalization as `app/services/user_importer.rb:42`".
- Classify as `required` when the shape will cause real drift, duplicated bug fixes, or blocks future changes. `good_to_have` for clarity/consistency polish.
- Do not emit shape findings that merely restate a lint rule the project already enforces.
- Do not invent abstractions the project doesn't already use — match the codebase's level of abstraction, not your preference.

## Edge cases

- Empty collections, single-element collections, very large inputs.
- Unicode, emoji, RTL, mixed casing, trimming whitespace.
- Pagination boundaries (first page, last page, out-of-range cursor).
- Auth boundaries: unauthenticated, authenticated-without-role, owner vs. non-owner.
- Feature flags on/off; partial rollout.
- Concurrent writes, duplicate submissions, retries.
- Network and IO failure (timeouts, 5xx, partial reads).

## Security

- Injection: SQL, shell, HTML, template, XPath, LDAP.
- AuthZ: every new endpoint/action checks the right policy/role.
- Secrets: no tokens/keys in code, logs, or test fixtures.
- PII: not logged, not sent to third parties beyond policy.
- SSRF: outbound URLs validated against allowlist.
- Deserialization: no `Marshal.load`, `pickle`, unsafe YAML, or `eval` on untrusted input.
- CSRF/CORS: settings match project norms for the endpoint class.

## Performance

- N+1 queries — look for loops over relations without `includes`/`preload`.
- Missing indexes for new `where`/`order`/`unique` usage.
- Unbounded collection loads (`.all`, `find_each` vs `each`).
- Synchronous work that belongs in a background job.
- Frontend: re-renders, missing memoization on expensive calc, oversized bundles, unkeyed lists.
- Caching: cache keys include all invalidation inputs; TTL present where needed.

## API and data contracts

- Backwards compatibility for public endpoints, events, feature flags, persisted formats.
- Migrations: safe for large tables (no locking adds without `algorithm: :concurrently` where applicable); data backfill plan present.
- Response shape changes reflected in serializers, TypeScript types, and consumers.
- Error codes/messages consistent with existing taxonomy.

## Tests

- Every new branch/condition covered by at least one test.
- Tests exercise behavior, not implementation.
- Fixtures/factories reused instead of ad-hoc duplicates.
- No flakiness: no `sleep`, no real network, deterministic time (`travel_to`, fake timers).
- Negative cases covered (invalid input, unauthorized, not found).
- Snapshot/visual changes intentional and reviewed.

## Submodules

- Pointer bump references a commit on an allowed branch (usually `main`/`develop`).
- Referenced submodule commit actually contains the changes the PR description claims.
- Parent repo changes and submodule changes are consistent (types, API shapes).
- No accidental downgrade (submodule pointer moving backwards).

## Classification guide

Mark **required** when:

- Correctness, security, data integrity, or privacy is at risk.
- Tests are missing for a new branch or would cover a regression.
- Project conventions (as enforced elsewhere) are broken.
- Public API / persisted format changes without a migration or compatibility plan.
- Submodule pointer is invalid or inconsistent.

Mark **good_to_have** when:

- Refactor that would improve clarity but is not blocking.
- Extracting a helper that is duplicated only twice (boundary case).
- Naming polish, comment improvements, micro-performance.
- Style suggestions not covered by the project's linters.
