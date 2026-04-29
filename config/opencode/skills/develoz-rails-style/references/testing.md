# Testing - Develoz Rails Style

## Core Philosophy

RSpec and FactoryBot are the default. Tests should read like executable behavior documentation, cover the real workflow, and fail for reasons a user or maintainer would care about.

Prefer confidence over implementation surveillance:
- Test observable behavior, not private method choreography
- Use factories for clear, local setup
- Keep specs explicit enough that the business case is obvious
- Include regression specs with bug and security fixes
- Keep coverage high without gaming coverage tools

## FactoryBot Defaults

Use FactoryBot for test data because it keeps setup close to the example and makes variations obvious.

```ruby
FactoryBot.define do
  factory :event do
    name { "Spring Tournament" }
    status { :open }
    starts_at { 2.weeks.from_now }

    association :client
  end
end
```

Prefer traits for meaningful business variants:

```ruby
factory :entry do
  event
  user
  status { :pending }

  trait :confirmed do
    status { :confirmed }
    confirmed_at { Time.current }
  end

  trait :cancelled do
    status { :cancelled }
    cancelled_at { Time.current }
  end
end
```

Avoid factory cleverness:
- Do not hide half the test scenario in callbacks
- Do not create expensive association trees by default
- Use transient attributes only when they make setup clearer
- Prefer `build_stubbed` only when persistence is irrelevant

## Spec Organization

Use the standard RSpec layout:

```text
spec/
├── factories/
├── models/
├── requests/
├── system/
├── jobs/
├── mailers/
├── helpers/
├── services/
└── support/
```

## Model Specs

Put domain behavior specs on the model that owns the behavior.

```ruby
RSpec.describe Entry do
  describe "#confirm!" do
    it "marks the entry as confirmed" do
      entry = create(:entry, :pending)

      entry.confirm!

      expect(entry).to be_confirmed
      expect(entry.confirmed_at).to be_present
    end
  end
end
```

Test validations and associations when they encode meaningful rules, not just because a matcher exists.

## Request Specs

Prefer request specs for controller behavior. They exercise routing, middleware, authentication, parameters, and response handling together.

```ruby
RSpec.describe "Entries" do
  describe "POST /entries" do
    it "creates an entry for the signed-in user" do
      user = create(:user)
      event = create(:event, :open)
      sign_in_as(user)

      expect {
        post event_entries_path(event), params: { entry: attributes_for(:entry) }
      }.to change(Entry, :count).by(1)

      expect(response).to redirect_to(entry_path(Entry.last))
    end
  end
end
```

Keep controller specs rare. Use them only when a project already uses them or when a narrow controller unit is genuinely clearer.

## Service Specs

Service specs should prove the workflow, not the internal call order.

```ruby
RSpec.describe RegistrationService do
  describe ".call" do
    it "creates a pending entry and returns success" do
      event = create(:event, :open)
      user = create(:user)

      result = described_class.call(event:, user:, params: valid_entry_params)

      expect(result).to be_success
      expect(result.entry).to be_persisted
      expect(result.entry).to be_pending
    end
  end
end
```

For transactional services, include failure-path specs that prove partial data is not persisted.

## System Specs

Use system specs for critical user flows and JavaScript/Turbo behavior that request specs cannot cover.

```ruby
RSpec.describe "Event registration" do
  it "lets a user register for an open event" do
    event = create(:event, :open)
    user = create(:user)
    sign_in_as(user)

    visit event_path(event)
    click_on I18n.t("entries.new.submit")

    expect(page).to have_text(I18n.t("entries.create.success"))
  end
end
```

Do not put every flow into system specs. They are slower and should cover the high-value paths.

## Jobs, Mailers, and Turbo

Assert enqueueing and delivery at behavior boundaries:

```ruby
it "enqueues the onboarding email" do
  user = create(:user)

  expect {
    SendOnboardingEmailJob.perform_later(user)
  }.to have_enqueued_job(SendOnboardingEmailJob).with(user)
end
```

For Turbo Streams, assert response structure in request specs or broadcast behavior in model/service specs when the broadcast is part of the contract.

## External APIs

Use WebMock/VCR or project-standard fakes for payment gateways, messaging providers, and other external services. Never let specs depend on live network calls.

```ruby
stub_request(:post, "https://api.example.test/charges")
  .to_return(status: 200, body: { id: "ch_123" }.to_json)
```

## Time and Determinism

Use Rails time helpers for time-sensitive behavior.

```ruby
travel_to Time.zone.local(2026, 1, 1, 10, 0, 0) do
  expect(entry.expires_at).to eq(30.minutes.from_now)
end
```

Avoid sleeps. Wait for observable UI changes in system specs instead.

## Coverage

High coverage is a safety net, not a game.

- Cover line and branch behavior for changed code
- Add regression specs for every bug fix
- Do not delete assertions to make coverage or specs pass
- Do not mock away the behavior being tested

## RSpec Style

Prefer:
- `describe` for methods or endpoints
- `context` for meaningful conditions
- `it` for one observable behavior
- `let` only when it improves readability
- `before` blocks only for setup shared by most examples

Avoid:
- Over-nested contexts
- Mystery guests hidden in shared setup
- Testing private methods directly
- Overuse of `receive_message_chain`
- Broad mocks of ActiveRecord models
