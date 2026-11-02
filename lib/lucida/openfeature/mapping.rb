# frozen_string_literal: true

require "time"

module Lucida
  module OpenFeature
    # Pure Lucida -> OpenFeature mappings (no OpenFeature classes).
    module Mapping
      module_function

      # Mirrors testdata/openfeature/reasons.json; the tests compare the two.
      REASONS = {
        "condition_match" => "TARGETING_MATCH", "sticky_bucket" => "CACHED", "no_condition_match" => "DEFAULT",
        "out_of_rollout" => "DEFAULT", "holdout" => "DEFAULT", "namespace_excluded" => "DEFAULT",
        "no_bucketing_key" => "DEFAULT", "prerequisite_failed" => "DEFAULT", "prerequisite_missing" => "DEFAULT",
        "prerequisite_cycle" => "ERROR", "inactive" => "DISABLED", "kill_switch" => "DISABLED",
        "app_context_excluded" => "DISABLED", "preview" => "STATIC", "user_preview" => "STATIC", "fallback" => "DEFAULT"
      }.freeze

      # A variant string under condition_match is SPLIT; an unknown reason is UNKNOWN.
      def reason(lucida, value)
        return "SPLIT" if lucida == "condition_match" && value.is_a?(String)

        REASONS.fetch(lucida.to_s, "UNKNOWN")
      end

      # FlagResult -> flagMetadata Hash (lucidaReason, conditionIndex when >= 0, requestId when set, evaluatedLocally).
      def metadata(res)
        m = { "lucidaReason" => res.reason.to_s }
        m["conditionIndex"] = res.condition_index if res.condition_index.to_i >= 0
        m["requestId"] = res.request_id if res.request_id && !res.request_id.empty?
        m["evaluatedLocally"] = res.locally_evaluated ? true : false
        m
      end

      # Evaluation attributes -> [person_properties, groups, group_properties]: `groups` and `groupProperties` are their
      # own maps, everything else is a person property (Time becomes ISO-8601, Structs/objects their fields).
      def split(fields)
        f = (fields || {}).transform_keys(&:to_s)
        groups = f.delete("groups")
        gprops = f.delete("groupProperties")
        [f.transform_values { |v| native(v) }, (groups.is_a?(Hash) ? groups : {}).to_h { |k, v| [k.to_s, v.to_s] },
         (gprops.is_a?(Hash) ? gprops : {}).to_h { |k, v| [k.to_s, native(v)] }]
      end

      def native(value)
        case value
        when Time then value.utc.iso8601(3)
        when Hash then value.to_h { |k, v| [k.to_s, native(v)] }
        when Array then value.map { |v| native(v) }
        when Struct then native(value.to_h)
        else value
        end
      end
    end
  end
end
