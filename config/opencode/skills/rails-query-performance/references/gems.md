# Query Debugging Gems

Reach for these only after the built-in tools (see `rails-tools.md`) aren't enough.

## Picking a gem

| Problem | Reach for |
| --- | --- |
| Catch N+1 in development | `bullet` |
| Catch N+1 in production safely | `prosopite` |
| Profile a slow page visually | `rack-mini-profiler` (+ optional `memory_profiler`, `stackprof`) |
| PostgreSQL dashboard: slow queries, missing / unused / bloated indexes | `pghero` |
| EXPLAIN ANALYZE formatting on older Rails (< 7.1) | `activerecord-explain-analyze` |

Never install more than one N+1 detector at a time — they fight each other.

## bullet

```ruby
# Gemfile
gem "bullet", group: :development
```

```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable        = true
  Bullet.alert         = true
  Bullet.bullet_logger = true
  Bullet.console       = true
  Bullet.rails_logger  = true
  Bullet.add_footer    = true
end
```

Bullet flags:

- N+1 queries
- Eager loading that is never used (wasteful `includes`)
- Places where a `counter_cache` would help

## rack-mini-profiler

```ruby
# Gemfile
gem "rack-mini-profiler"
gem "memory_profiler" # optional, memory snapshots
gem "stackprof"       # optional, flamegraphs
```

Shows a speed badge in the top corner of every page with request time, a breakdown of every SQL query, and the Ruby stack. Combine with `stackprof` for CPU flamegraphs.

## prosopite

Safer in production than Bullet — designed to be low-overhead and to catch real N+1 patterns without tripping on the edge cases Bullet struggles with.

```ruby
# Gemfile
gem "prosopite"
```

```ruby
# config/environments/production.rb
config.after_initialize do
  Prosopite.rails_logger     = true
  Prosopite.prosopite_logger = Logger.new("log/prosopite.log")
end
```

Wrap a specific block of code to scan it:

```ruby
Prosopite.scan
# ... suspected code ...
Prosopite.finish
```

## activerecord-explain-analyze

On Rails < 7.1, Rails' own `explain` does not expose `:analyze`. This gem fills the gap:

```ruby
# Gemfile
gem "activerecord-explain-analyze"

# Usage
User.where(status: "active").explain_analyze
```

On Rails 7.1+, prefer `explain(:analyze)` and skip this gem.

## pghero

PostgreSQL performance dashboard mounted inside the Rails app:

```ruby
# Gemfile
gem "pghero"

# config/routes.rb
mount PgHero::Engine, at: "pghero"
```

Surfaces:

- Slow queries (leverages `pg_stat_statements`; enable it first — see `databases.md`)
- Missing indexes suggested from query patterns
- Unused indexes (safe-to-drop candidates)
- Index bloat
- Connection statistics

Protect the route with authentication before shipping.
