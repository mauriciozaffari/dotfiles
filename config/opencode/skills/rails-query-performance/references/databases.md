# Database-Specific Tools

Load this reference when adapter-specific plan output, slow query logs, or analyzers are required.

## Contents

- [PostgreSQL](#postgresql)
- [MySQL](#mysql)
- [SQLite](#sqlite)
- [Solid Cache note](#solid-cache-note)
- [Production APM](#production-apm)

## PostgreSQL

### pg_stat_statements

Tracks execution statistics for every SQL statement. Usually the first stop on a slow production app.

```sql
-- One-time setup (superuser)
CREATE EXTENSION pg_stat_statements;
```

Find the worst queries:

```sql
SELECT
  query,
  calls,
  total_exec_time / 1000 AS total_seconds,
  mean_exec_time  / 1000 AS avg_seconds,
  rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;
```

Use `pg_stat_statements_reset()` between experiments.

### EXPLAIN (ANALYZE, BUFFERS)

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM users WHERE email = 'x@example.com';
```

What to look for:

- **Seq Scan** on a large table — add an index or rewrite the predicate.
- **Index Scan** / **Index Only Scan** — the index is doing its job.
- **Nested Loop** — cheap on small sides, catastrophic on large ones.
- **Hash Join** — fine for larger sets when memory allows.
- **Buffers** — high `read` vs `hit` means cold cache / I/O bound.

### auto_explain

Auto-log plans for slow queries in production:

```sql
LOAD 'auto_explain';
SET auto_explain.log_min_duration = '100ms';
SET auto_explain.log_analyze      = true;
```

Configure at the cluster level via `postgresql.conf` for persistence.

### pgBadger

Log analyzer that turns a PostgreSQL log into an HTML performance report:

```bash
pgbadger /var/log/postgresql/postgresql.log -o report.html
```

Good for after-the-fact analysis or periodic audits.

### pganalyze (SaaS)

Continuous monitoring with query insights, index advisor, plan visualization, and anomaly detection. Reach for it when logs + `pg_stat_statements` aren't enough signal and the team will use a dashboard.

### PgHero

Rails-side dashboard; see `gems.md`.

## MySQL

### EXPLAIN / EXPLAIN ANALYZE (8.0+)

```sql
EXPLAIN ANALYZE
SELECT * FROM users WHERE status = 'active';
```

Key columns:

- `type: ALL` — full table scan.
- `type: index` — full index scan (better than ALL, still not great).
- `type: ref` — index lookup on non-unique key.
- `type: eq_ref` — unique / primary key lookup (ideal for joins).
- `Extra: Using filesort` — sorting without an index; consider a composite index matching the `ORDER BY`.
- `Extra: Using temporary` — a temp table is being built; reshape the query or add an index.

### Performance Schema

```sql
SELECT
  DIGEST_TEXT,
  COUNT_STAR AS calls,
  SUM_TIMER_WAIT / 1000000000000 AS total_seconds,
  AVG_TIMER_WAIT / 1000000000000 AS avg_seconds
FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;
```

### Slow query log

```ini
# my.cnf
slow_query_log                = 1
slow_query_log_file           = /var/log/mysql/slow.log
long_query_time               = 0.1
log_queries_not_using_indexes = 1
```

### pt-query-digest

Part of Percona Toolkit. Aggregates the slow query log into a ranked report:

```bash
pt-query-digest /var/log/mysql/slow.log > report.txt
```

## SQLite

Rails 8 promoted SQLite to a first-class production database. The adapter sets sensible defaults:

```text
PRAGMA journal_mode   = WAL       -- concurrent reads while writing
PRAGMA synchronous    = NORMAL
PRAGMA mmap_size      = 128MB     -- memory-mapped I/O for reads
PRAGMA busy_timeout   = 5000
```

Most Rails 8 SQLite apps perform well without manual tuning. Before changing a PRAGMA, prove it matters with a benchmark.

### EXPLAIN QUERY PLAN

```sql
EXPLAIN QUERY PLAN
SELECT * FROM users WHERE email = 'x@example.com';
```

Read the plan:

- **SCAN** — full table scan.
- **SEARCH** — using an index.
- **USING INDEX** — covering index (best case: the index satisfies the query without touching the table).

### sqlite3_analyzer

Dumps schema / storage statistics for a database file:

```bash
sqlite3_analyzer database.sqlite3
```

## Solid Cache note

Rails 8 uses Solid Cache by default — cache reads and writes are SQL queries against `solid_cache_entries`. When analyzing slow query logs:

- Queries on `solid_cache_entries` are expected; they are not an N+1.
- For high-traffic apps, split the cache into its own database to reduce contention:

```yaml
# config/database.yml
production:
  primary:
    <<: *default
    database: my_app_production
  cache:
    <<: *default
    database: my_app_production_cache
    migrations_paths: db/cache_migrate
```

## Production APM

- **Scout APM** and **New Relic** — automatic slow query detection, query traces with source context, historical trends, alerting.

Custom metrics via StatsD:

```ruby
# config/initializers/query_metrics.rb
ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  StatsD.timing("database.query", event.duration)
  StatsD.increment("database.slow_queries") if event.duration > 100
end
```
