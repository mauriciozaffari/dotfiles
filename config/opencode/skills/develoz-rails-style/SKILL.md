---
name: develoz-rails-style
description: Use this skill when writing, reviewing, or refactoring Ruby and Rails code in Develoz's preferred Rails style. Applies to Rails models, controllers, services, jobs, helpers, mailers, views, tests, routing, and architecture. Emphasizes clear Rails conventions, rich domain models, pragmatic service objects, RESTful defaults with practical exceptions, Hotwire, Tailwind, RSpec, FactoryBot, and simple infrastructure choices.
---

<objective>
Apply Develoz Rails conventions to Ruby and Rails code across any Rails application. Favor boring, explicit Rails code that is easy to change: rich models, thin controllers, well-scoped services, readable tests, and clear UI built with Hotwire and Tailwind when useful.
</objective>

<essential_principles>
## Core Philosophy

"The best code is obvious in retrospect."

**Rails is the center of gravity:**
- Rich domain models for behavior that naturally belongs to a record
- Controllers that coordinate HTTP, authorization, redirects, renders, and strong params
- Service objects for business logic that does not belong to any particular model
- Concerns for horizontal behavior shared across models/controllers
- Current attributes for request-scoped state in new work
- Hotwire first for interactivity; add custom JavaScript only where it earns its keep
- Tailwind is welcome when it improves speed and consistency
- RSpec and FactoryBot are the testing defaults

**What to avoid:**
- Controllers packed with business logic
- Service objects that merely rename a single model method
- Custom actions when a clean noun-resource fits better
- Deep route nesting unless the hierarchy materially improves clarity
- Hardcoded user-facing strings in views/controllers/helpers
- Premature abstractions, clever metaprogramming, and framework fights

**Development philosophy:**
- Ship small, verify, refine
- Fix root causes, not symptoms
- Prefer explicit dependencies and readable data flow
- Use database constraints and model validations together where appropriate
- Add gems when they solve a real problem better than simple Rails code
</essential_principles>

<intake>
What are you working on?

1. **Controllers** - REST mapping, custom actions, concerns, Turbo responses, authorization
2. **Models** - Domain behavior, concerns, callbacks, scopes, state, validations
3. **Views & Frontend** - Turbo, Stimulus, Tailwind, partials, forms
4. **Architecture** - Routing, multi-tenancy, authentication, jobs, caching, Current attributes
5. **Testing** - RSpec, FactoryBot, request/model/system specs, coverage
6. **Gems & Dependencies** - What to use, avoid, or evaluate
7. **Code Review** - Review code against Develoz Rails style
8. **General Guidance** - Philosophy and conventions

**Specify a number or describe your task.**
</intake>

<routing>

| Response | Reference to Read |
|----------|-------------------|
| 1, controller | [controllers.md](./references/controllers.md) |
| 2, model | [models.md](./references/models.md) |
| 3, view, frontend, turbo, stimulus, css, tailwind | [frontend.md](./references/frontend.md) |
| 4, architecture, routing, auth, job, cache, current | [architecture.md](./references/architecture.md) |
| 5, test, testing, rspec, factory | [testing.md](./references/testing.md) |
| 6, gem, dependency, library | [gems.md](./references/gems.md) |
| 7, review | Read all relevant references, then review code |
| 8, general task | Read relevant references based on context |

**After reading relevant references, apply patterns to the user's code.**
</routing>

<quick_reference>
## Naming Conventions

**Verbs:** `entry.confirm`, `charge.capture`, `event.publish` (not vague `process` methods)

**Predicates:** `entry.confirmed?`, `event.open?`, `user.admin?`

**Concerns:** Adjectives describing capability (`Publishable`, `Sluggable`, `Filterable`)

**Controllers:** Nouns matching resources (`Entries::ConfirmationsController` when the noun-resource is clear)

**Services:** Nouns or process names for cross-model workflows (`RegistrationService`, `RefundService`, `PaymentGateway::Capture`)

**Scopes:**
- `chronologically`, `reverse_chronologically`, `alphabetically`, `latest`
- `preloaded` for standard eager loading
- `active`, `archived`, `confirmed` for business terms

## REST Mapping

Prefer noun resources when the action is durable and independently meaningful:

```ruby
POST /entries/:id/confirmation    # create confirmation
DELETE /entries/:id/confirmation  # destroy confirmation
POST /events/:id/publication      # publish event
```

Custom member/collection actions are acceptable when they are clearer than inventing awkward resources:

```ruby
post :approve
post :reject
post :simulate_payment
post :update_positions
```

## Ruby Syntax Preferences

```ruby
# Symbol arrays do not use inner spaces
before_action :set_event, only: %i[show edit update destroy]

class EventsController < ApplicationController
  private

  def set_event
    @event = Event.find(params[:id])
  end
end

# Prefer if/elsif or case with an explicit expression
entries = if params[:before].present?
            Entry.page_before(params[:before])
          else
            Entry.latest
          end

# Bang methods for fail-fast inside transactions/setup
Entry.create!(entry_params)
```

## Key Patterns

**Current Attributes for new request-scoped state:**

```ruby
Current.user
Current.account
Current.request_id
```

**Service objects for cross-model workflows:**

```ruby
result = RegistrationService.call(event:, user:, params:)

if result.success?
  redirect_to result.entry
else
  render :new, status: :unprocessable_entity
end
```

**Authorization stays simple:**

```ruby
class User < ApplicationRecord
  def can_administer?(event)
    admin? || event.owner == self
  end
end
```
</quick_reference>

<reference_index>
## Domain Knowledge

All detailed patterns in `references/`:

| File | Topics |
|------|--------|
| [controllers.md](./references/controllers.md) | REST mapping, custom actions, concerns, Turbo responses, HTTP caching |
| [models.md](./references/models.md) | Domain behavior, concerns, callbacks, scopes, POROs, authorization, broadcasting |
| [frontend.md](./references/frontend.md) | Turbo Streams, Stimulus controllers, Tailwind, partials, caching |
| [architecture.md](./references/architecture.md) | Routing, authentication, jobs, Current attributes, caching, database patterns |
| [testing.md](./references/testing.md) | RSpec, FactoryBot, model/request/system specs, coverage patterns |
| [gems.md](./references/gems.md) | Dependency choices, decision framework, Gemfile examples |
</reference_index>

<success_criteria>
Code follows Develoz Rails style when:
- Controllers are thin and mostly HTTP orchestration
- Domain behavior lives on models when the ownership is obvious
- Service objects handle business workflows without a natural single-model home
- RESTful resources are preferred, but custom actions are allowed when clearer
- Current attributes are used for new request-scoped state
- Tests use RSpec and FactoryBot with behavior-focused examples
- Turbo/Stimulus solve interactivity before reaching for a SPA
- Tailwind classes are static and discoverable; helper variants are explicit when needed
- Authorization is simple and readable
- Jobs are small entry points into model/service behavior
</success_criteria>

<credits>
Maintained as Develoz's Rails engineering preference guide.
</credits>
