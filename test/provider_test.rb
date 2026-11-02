# frozen_string_literal: true

require "minitest/autorun"
require "json"
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__), File.expand_path("../../ruby/lib", __dir__))
require "lucida/openfeature"

DATA = ENV["LUCIDA_TESTDATA"] || File.expand_path("../../../testdata", __dir__)

class ProviderTest < Minitest::Test
  Ctx = Struct.new(:targeting_key, :fields)

  def flag(key, **extra)
    { "key" => key, "type" => "boolean", "active" => true, "salt" => "s", "aggregation" => { "kind" => "person" },
      "conditions" => [{ "rollout_pct" => 100 }] }.merge(extra.transform_keys(&:to_s))
  end

  def setup
    @lc = Lucida::Client.new("k", secret_key: "s", test_mode: [flag("on"), flag("off", active: false)],
                                  fallbacks: { "ghost" => true })
    @p = Lucida::OpenFeature::Provider.new(@lc)
    @ctx = Ctx.new("user-1", { "plan" => "pro" })
  end

  def test_reason_table_from_shared_json
    table = JSON.parse(File.read(File.join(DATA, "openfeature/reasons.json")))["reasons"]
    table.each do |raw, row|
      assert_equal row["reason"], Lucida::OpenFeature::Mapping.reason(raw, true), raw
      assert_equal row["variant_reason"] || row["reason"], Lucida::OpenFeature::Mapping.reason(raw, "v"), raw
    end
    assert_equal "UNKNOWN", Lucida::OpenFeature::Mapping.reason("brand_new", true)
    assert_equal table.size - 1, Lucida::OpenFeature::Mapping::REASONS.size
  end

  def test_served_flag_and_metadata
    r = @p.fetch_boolean_value(flag_key: "on", default_value: false, evaluation_context: @ctx)
    assert_equal true, r.value
    assert_equal "TARGETING_MATCH", r.reason
    assert_nil r.error_code
    assert_equal({ "lucidaReason" => "condition_match", "conditionIndex" => 0, "evaluatedLocally" => true }, r.flag_metadata)
    assert_equal "DISABLED", @p.fetch_boolean_value(flag_key: "off", default_value: true, evaluation_context: @ctx).reason
  end

  def test_fallback_keeps_the_value_without_error
    r = @p.fetch_boolean_value(flag_key: "ghost", default_value: false, evaluation_context: @ctx)
    assert_equal [true, "DEFAULT", nil], [r.value, r.reason, r.error_code]
    assert_equal "fallback", r.flag_metadata["lucidaReason"]
  end

  def test_errors
    r = @p.fetch_boolean_value(flag_key: "nope", default_value: false, evaluation_context: @ctx)
    assert_equal ["ERROR", "FLAG_NOT_FOUND"], [r.reason, r.error_code.to_s]
    assert_equal "TYPE_MISMATCH", @p.fetch_string_value(flag_key: "on", default_value: "d", evaluation_context: @ctx).error_code.to_s
    assert_equal "TARGETING_KEY_MISSING",
                 @p.fetch_boolean_value(flag_key: "on", default_value: false, evaluation_context: Ctx.new(nil, {})).error_code.to_s
  end

  def test_context_split
    person, groups, gprops = Lucida::OpenFeature::Mapping.split(
      "plan" => "pro", "at" => Time.utc(2020, 1, 2, 3, 4, 5), "groups" => { company: "acme" }, "groupProperties" => { "company" => { seats: 5 } }
    )
    assert_equal({ "plan" => "pro", "at" => "2020-01-02T03:04:05.000Z" }, person)
    assert_equal [{ "company" => "acme" }, { "company" => { "seats" => 5 } }], [groups, gprops]
  end

  def test_track_captures
    @p.track("purchase", evaluation_context: @ctx, tracking_event_details: { "value" => 12.5, "plan" => "pro" })
    e = @lc.sink.events.last
    assert_equal ["purchase", "user-1", 12.5, "pro"], [e["event"], e["distinct_id"], e["properties"]["$value"], e["properties"]["plan"]]
    refute e["properties"].key?("value")
  end
end
