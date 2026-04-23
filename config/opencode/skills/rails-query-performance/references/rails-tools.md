# Rails Built-in Tools

Use these before reaching for gems. They require zero dependencies.

## Contents

- [explain and explain(:analyze)](#explain)
- [load_async and async aggregates](#load_async)
- [Slow query logger via ActiveSupport::Notifications](#slow-query-logger)
- [Query log tags](#query-log-tags)
- [Strict loading](#strict-loading)
- [Benchmarking changes](#benchmarking)

## explain

Get the database's plan for any relation:

```ruby
User.where(status: "active").explain
```

Rails 7.1+ accepts explain options and forwards them to the adapter:

```ruby
# PostgreSQL
User.where(status: "active").explain(:analyze, :verbose, :buffers)

# MySQL 8.0+
User.where(status: "active").explain(:analyze)
```

`:analyze` executes the query and prints real timings and row counts instead of estimates. Use it on representative data, not a tiny dev DB.

## load_async

Rails 7+ can dispatch independent queries on a thread pool so they run in parallel:

```ruby
@users = User.where(status: "active").load_async
@posts = Post.where(published: true).load_async
@stats = Stat.where(date: Date.today).load_async
```

Async aggregates (Rails 7.1+):

```ruby
active_count  = User.where(status: "active").async_count
total_revenue = Order.async_sum(:amount)
oldest_user   = User.async_minimum(:created_at)
```

Configure the executor in production:

```ruby
# config/environments/production.rb
config.active_record.async_query_executor  = :global_thread_pool
config.active_record.global_executor_concurrency = 4
```

Use this when a controller action or view fetches several independent collections. It will not help a single serial query.

## Slow query logger

Subscribe to `sql.active_record` to log anything slow. Drop this in an initializer:

```ruby
# config/initializers/slow_query_logger.rb
ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)
  if event.duration > 100 # ms
    Rails.logger.warn "SLOW QUERY (#{event.duration.round(2)}ms): #{event.payload[:sql]}"
  end
end
```

Development-only variant logs at a lower threshold so issues surface early.

## Query log tags

Rails 7 ships the built-in replacement for the old `marginalia` gem. Annotate every SQL statement with where it came from:

```ruby
# config/application.rb
config.active_record.query_log_tags_enabled = true
config.active_record.query_log_tags = [:application, :controller, :action, :job]
```

Queries then show up as:

```sql
SELECT * FROM users WHERE id = 1
/*application:MyApp,controller:users,action:show*/
```

This is invaluable when tailing production logs or reading `pg_stat_statements` — you can trace a hot query back to the exact action or job.

## Strict loading

Catch N+1 at the source. Rails 6.1+:

```ruby
# Per query
User.strict_loading.includes(:posts).each do |u|
  u.posts    # OK (eager loaded)
  u.comments # raises StrictLoadingViolationError
end

# Or globally in development
# config/environments/development.rb
config.active_record.strict_loading_by_default = true
```

Modes:

- `:all` — raises on any lazy-loaded association (strict).
- `:n_plus_one_only` — only raises on patterns that cause N+1, still allows `belongs_to` lazy loads. More realistic for large apps.

```ruby
user.strict_loading!(mode: :n_plus_one_only)

# Or
config.active_record.strict_loading_by_default = true
config.active_record.strict_loading_mode       = :n_plus_one_only
```

Safe to enable in production by changing the violation action:

```ruby
# config/environments/production.rb
config.active_record.action_on_strict_loading_violation = :log
```

## Benchmarking

For a single comparison:

```ruby
require "benchmark"

Benchmark.bm(15) do |x|
  x.report("before:") { User.where(status: "active").to_a }
  x.report("after:")  { User.where(status: "active").to_a }
end
```

For statistically meaningful numbers, prefer `benchmark-ips`:

```ruby
require "benchmark/ips"

Benchmark.ips do |x|
  x.report("before") { User.where(status: "active").to_a }
  x.report("after")  { User.where(status: "active").to_a }
  x.compare!
end
```

Always run on a dataset shaped like production. A query that is fast on 100 rows can still do a seq scan on 10M.
