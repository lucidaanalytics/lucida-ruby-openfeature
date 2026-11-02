# frozen_string_literal: true

require "time"

module Lucida
  module OpenFeature
    # OpenFeature server provider over Lucida::Client. targeting_key is the distinct id; the attribute "groups"
    # (group_type => key) and "groupProperties" (group_type => Hash) feed Lucida groups, every other attribute is a person
    # property. Integer/float/number/object flags read the flag's JSON payload; boolean and string flags read its value.
    class Provider
      attr_reader :client

      def initialize(client)
        @client = client
      end

      def metadata = ::OpenFeature::SDK::Provider::ProviderMetadata.new(name: "Lucida")

      def init; end

      def shutdown; end

      def fetch_boolean_value(flag_key:, default_value:, evaluation_context: nil)
        resolve(flag_key, default_value, evaluation_context, false) { |v| [true, false].include?(v) }
      end

      def fetch_string_value(flag_key:, default_value:, evaluation_context: nil)
        resolve(flag_key, default_value, evaluation_context, false) { |v| v.is_a?(String) }
      end

      def fetch_number_value(flag_key:, default_value:, evaluation_context: nil)
        resolve(flag_key, default_value, evaluation_context, true) { |v| v.is_a?(Numeric) }
      end

      def fetch_integer_value(flag_key:, default_value:, evaluation_context: nil)
        resolve(flag_key, default_value, evaluation_context, true) { |v| v.is_a?(Integer) }
      end

      def fetch_float_value(flag_key:, default_value:, evaluation_context: nil)
        resolve(flag_key, default_value, evaluation_context, true) { |v| v.is_a?(Numeric) }
      end

      def fetch_object_value(flag_key:, default_value:, evaluation_context: nil)
        resolve(flag_key, default_value, evaluation_context, true) { |v| v.is_a?(Hash) || v.is_a?(Array) }
      end

      # OpenFeature tracking: event = name, distinct id = targeting key, properties = the details' fields plus "$value"
      # when the details carry a value. Dropped without a targeting key.
      def track(tracking_event_name, evaluation_context: nil, tracking_event_details: nil)
        id = evaluation_context&.targeting_key
        return if id.nil? || id.to_s.empty?

        d = tracking_event_details
        fields = d.respond_to?(:fields) ? d.fields : (d || {})
        props = Mapping.native(fields.to_h.transform_keys(&:to_s))
        value = d.respond_to?(:value) ? d.value : props.delete("value")
        props["$value"] = value unless value.nil?
        @client.capture(id, tracking_event_name, props, groups: Mapping.split(evaluation_context.fields)[1].then { |g| g.empty? ? nil : g })
      end

      private

      def resolve(key, default, context, from_payload)
        id = context&.targeting_key
        return error(default, "TARGETING_KEY_MISSING", "targeting_key is required") if id.nil? || id.to_s.empty?

        person, groups, gprops = Mapping.split(context.fields)
        res = @client.get_feature_flag_details(key, id, person_properties: person, groups: groups, group_properties: gprops)
        return error(default, "FLAG_NOT_FOUND", "flag #{key} not found") if res.nil?

        value = from_payload && res.reason != "fallback" ? res.payload : res.value
        return error(default, "TYPE_MISMATCH", "flag #{key} does not resolve to the requested type", res) unless yield(value)

        details(value, Mapping.reason(res.reason, res.value), res)
      end

      def error(default, code, message, res = nil)
        details(default, "ERROR", res, error_code: code, error_message: message)
      end

      def details(value, reason, res, **err)
        ::OpenFeature::SDK::Provider::ResolutionDetails.new(
          value: value, reason: reason, variant: res&.variant, flag_metadata: res && Mapping.metadata(res), **err
        )
      end
    end
  end
end
