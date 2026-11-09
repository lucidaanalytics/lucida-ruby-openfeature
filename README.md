# lucida-openfeature (Ruby)

## Install

From GitHub, [lucidaanalytics/lucida-ruby-openfeature](https://github.com/lucidaanalytics/lucida-ruby-openfeature), release `v0.1.0`:

```ruby
# Gemfile (the provider needs the core gem)
gem "lucida", git: "https://github.com/lucidaanalytics/lucida-ruby.git", tag: "v0.1.0"
gem "lucida-openfeature", git: "https://github.com/lucidaanalytics/lucida-ruby-openfeature.git", tag: "v0.1.0"
```

The RubyGems package `lucida-openfeature` is coming.


OpenFeature server provider over the Lucida Ruby SDK. Pinned to `openfeature-sdk ~> 0.4` (Apache-2.0).

```ruby
require "lucida/openfeature"

lc = Lucida::Client.new("lc_pk_...", secret_key: "lc_sk_...", fallbacks: { "new-nav" => false })
OpenFeature::SDK.configure { |c| c.set_provider(Lucida::OpenFeature::Provider.new(lc)) }
client = OpenFeature::SDK.build_client
ctx = OpenFeature::SDK::EvaluationContext.new(targeting_key: "user-1", plan: "pro", groups: { company: "acme" })
client.fetch_boolean_value(flag_key: "new-nav", default_value: false, evaluation_context: ctx)
```

- Context: `targeting_key` is the distinct id (missing: `TARGETING_KEY_MISSING`); `groups` (type => key) and
  `groupProperties` (type => Hash) feed Lucida groups; every other attribute is a person property.
- Boolean and string flags read the flag value; integer, float, number and object flags read its JSON payload. A wrong
  type is `TYPE_MISMATCH`, an unknown flag `FLAG_NOT_FOUND` (reason `ERROR`).
- Reasons map through `testdata/openfeature/reasons.json` (`condition_match` with a variant is `SPLIT`). A client
  `fallbacks` value is returned with reason `DEFAULT` and no error. `flag_metadata`: `lucidaReason`, `conditionIndex`,
  `requestId`, `evaluatedLocally`.
- `track(name, evaluation_context:, tracking_event_details:)` captures the event for the targeting key (`value` becomes
  `$value`). This OpenFeature SDK has no provider events, so none are emitted.

Tests: `ruby -Ilib -Itest test/provider_test.rb` (needs `openfeature-sdk`).

---

This repository is a read-only mirror of the Lucida monorepo (synced by a script, never edited by hand); releases and provenance attestations are built here by GitHub Actions. Issues are welcome, changes land upstream.
