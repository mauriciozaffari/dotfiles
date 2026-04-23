---
name: rails-query-performance
description: Debug and optimize slow ActiveRecord queries in a Ruby on Rails application. Use this skill when the user reports slow pages or jobs, suspects N+1 queries, asks to "optimize", "speed up", "profile", "add indexes", or "explain" an ActiveRecord query, or mentions tools like Bullet, rack-mini-profiler, pghero, pg_stat_statements, EXPLAIN/EXPLAIN ANALYZE, load_async, strict_loading, or query log tags. Also triggers on database-specific performance questions for PostgreSQL, MySQL, or SQLite inside a Rails codebase.
---

# Rails Query Performance

Debug slow ActiveRecord queries by starting with Rails built-ins, then escalating to ecosystem gems and database-specific tooling only as needed.

## Quick Workflow

Follow this order. Do NOT jump ahead — each step informs the next.

### 1. Identify the slow query

- Check logs for the request / job and note concrete SQL + timings.
- In development, subscribe to `sql.active_record` to surface anything over a threshold. See [references/rails-tools.md](references/rails-tools.md#slow-query-logger).
- In production, use APM (Scout / New Relic) or `pg_stat_statements` to find the worst offenders. See [references/databases.md](references/databases.md#postgresql).

### 2. Reproduce and inspect

- Reproduce the call in `rails console` with the exact inputs.
- Check for N+1 using `bullet` (dev) or `prosopite` (dev/prod). See [references/gems.md](references/gems.md).
- Run `.explain(:analyze)` (Rails 7.1+) on the relation to see the execution plan. See [references/rails-tools.md](references/rails-tools.md#explain).

### 3. Decide the fix by category

| Symptom | Likely fix |
| --- | --- |
| N+1 on association | `includes` / `preload` / `eager_load`; enable `strict_loading` to prevent regressions |
| Seq Scan / type: ALL | Add index; rewrite WHERE to be sargable |
| Over-fetching columns | `select(:id, :col)` or `pluck(:col)` |
| Existence check via `.present?` or `.any?` | `.exists?` |
| Iterating large result sets | `find_each` / `in_batches` |
| Many independent queries per request | `load_async` + async aggregates |
| Counts recomputed repeatedly | `counter_cache` |

### 4. Apply and verify

- Add the migration / code change in the smallest diff possible.
- Re-run the reproduction and compare with `benchmark-ips` (preferred) or `Benchmark.bm`. See [references/rails-tools.md](references/rails-tools.md#benchmarking).
- Re-check the EXPLAIN plan to confirm index usage / join strategy changed as expected.

### 5. Prevent regression

- Turn on `query_log_tags_enabled` so future slow queries carry controller/action/job context. See [references/rails-tools.md](references/rails-tools.md#query-log-tags).
- Keep `strict_loading` on for the relation, model, or globally in development.
- Add a regression spec asserting the query count (e.g. `expect { ... }.to make_database_queries(count: 1)`).

## When to Load Which Reference

- Rails-only tactics, no gems → [references/rails-tools.md](references/rails-tools.md)
- Deciding which gem to add → [references/gems.md](references/gems.md)
- Adapter-specific EXPLAIN output, slow query logs, and analyzers → [references/databases.md](references/databases.md)

## Guardrails

- Always look at the **actual SQL and plan** before changing code; do not guess.
- Prefer **adding an index or using `includes`** over caching a symptom.
- Never use `update_all` / `delete_all` to skirt validations when fixing performance — that is a different problem class.
- On Rails 8, expect `solid_cache_entries` queries in logs; that is the cache store, not a bug.
- Measure twice: a plan change without a benchmark is not a fix.
