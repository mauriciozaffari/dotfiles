# Gems and Dependencies - Develoz Rails Style

## Core Rails Stack

Default to Rails-native pieces unless a gem clearly improves the result:

- `turbo-rails` and `stimulus-rails` for interactivity
- `tailwindcss-rails` when Tailwind is the chosen styling system
- `propshaft` for modern Rails asset handling
- `solid_queue` as the default background job backend for Rails 8 apps
- `solid_cache` and `solid_cable` when database-backed infrastructure is enough
- `rspec-rails` and `factory_bot_rails` for testing

## Dependency Decision Framework

Before adding a gem, ask:

1. **Can Rails already do this clearly?**
   - ActiveRecord, ActiveJob, ActionMailer, ActiveStorage, and Hotwire cover a lot.

2. **Does the gem remove real complexity or add it?**
   - A small focused gem can be excellent.
   - A framework-within-the-framework needs a stronger reason.

3. **Will the team understand and operate it?**
   - Consider upgrades, debugging, deployment, observability, and failure modes.

4. **Does it add infrastructure?**
   - Redis, Elasticsearch, external queues, and SaaS dependencies are fine when justified.
   - Prefer simpler infrastructure when it satisfies the product need.

5. **Is it maintained and conventional?**
   - Prefer widely used, focused, maintained gems over abandoned or magical dependencies.

## Authentication

Do not prescribe a universal auth library. Follow the application's existing authentication approach.

Good defaults:
- Keep auth flows explicit and test-covered
- Keep controllers thin; put token/session lifecycle in models or focused services
- Prefer secure Rails primitives (`has_secure_password`, signed/encrypted cookies, secure tokens)
- Avoid introducing Devise, Clearance, or custom auth into an existing app without a clear migration reason

## Authorization

Start simple.

```ruby
class User < ApplicationRecord
  def can_administer?(event)
    admin? || event.owner == self
  end
end
```

Policy gems such as Pundit are acceptable when permissions become broad enough that model methods stop being clear. Avoid adding a policy layer for two role checks.

## Background Jobs and Redis

SolidQueue is the preferred default for new Rails 8 apps because it keeps operational complexity low and integrates with ActiveJob.

Sidekiq and Redis are acceptable when the application needs their strengths:
- high-throughput queues
- mature retry/dead-set tooling
- Redis-backed rate limiting or pub/sub
- existing production infrastructure built around Redis

Do not ban infrastructure. Just make it earn its keep.

## Caching

Use the simplest cache that meets the need:

- Fragment/HTTP caching first
- Solid Cache when database-backed caching is enough
- Redis when latency, sharing, or existing infrastructure justifies it

## View Layer

Partials are the default. ViewComponent or Phlex-style component systems are acceptable when a project already uses them or when the view logic is complex enough to justify a component boundary.

Do not introduce a component framework just to wrap a small partial.

## Frontend

Hotwire first:

```ruby
gem "turbo-rails"
gem "stimulus-rails"
```

Tailwind is acceptable and often preferred for product UI speed. Keep classes static and discoverable so Tailwind can compile them.

React/Vue/SPAs are acceptable only when the product surface needs client-side state and interaction beyond what Hotwire can reasonably provide.

## Testing

RSpec and FactoryBot are the defaults:

```ruby
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
end
```

Add supporting gems when useful:
- `simplecov` for coverage
- `webmock` or `vcr` for external APIs
- `capybara` and Selenium/cuprite for system specs
- `parallel_tests` for large suites

## Service Objects

Use service objects for business logic that does not naturally belong to a single model:

- checkout and registration workflows
- payment/refund orchestration
- external gateway adapters
- multi-model transactions
- imports/exports and batch processes

Avoid service objects that only rename a model method:

```ruby
# Prefer this
entry.confirm!(by: Current.user)

# Over this
EntryConfirmationService.call(entry, Current.user)
```

When a service returns a result, make success/failure explicit:

```ruby
Result = Data.define(:success?, :entry, :error)
```

## Forms and Validation

Use model validations for persistent business rules. Use form objects only when the form does not map cleanly to one model or coordinates multiple records.

## The Philosophy

Use gems deliberately. Rails plus a few well-chosen dependencies beats both extremes: not-invented-here custom code and dependency sprawl.
