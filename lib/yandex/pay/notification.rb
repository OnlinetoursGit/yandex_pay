# frozen_string_literal: true

require 'openssl'

module Yandex
  module Pay
    # Yandex::Pay::Notification
    # Handles webhook notifications from Yandex Pay
    class Notification
      class UnsupportedTypeError < StandardError; end

      DEFAULT_ALGORITHM = 'sha256'
      SUPPORTED_EVENT_TYPES = %w[
        ORDER_STATUS_UPDATED
        OPERATION_STATUS_UPDATED
        SUBSCRIPTION_STATUS_UPDATED
        REFUND_STATUS_UPDATED
      ].freeze

      attr_reader :event_type, :order_id, :operation_id, :subscription_id,
                  :status, :reason, :data

      def initialize(data:)
        @raw_data = data
        @data = Utils.deep_transform_keys(data) { |k| Utils.snake_case(k.to_s) }
        
        @event_type = @data['event'] || @data['event_type']
        
        unless SUPPORTED_EVENT_TYPES.include?(@event_type)
          raise UnsupportedTypeError, "Unsupported notification type: #{@event_type}."
        end

        parse_notification
      end

      def success?
        %w[SUCCESS CAPTURED COMPLETED].include?(status)
      end

      def pending?
        %w[PENDING WAITING PROCESSING].include?(status)
      end

      def failed?
        %w[FAILED CANCELLED REJECTED].include?(status)
      end

      # Validate webhook signature
      # @param secret_key [String] webhook secret key
      # @param signature [String] signature from request header
      # @return [Boolean]
      def valid?(secret_key:, signature:)
        return false if signature.nil? || signature.empty?

        expected_signature = compute_signature(secret_key)
        secure_compare(signature, expected_signature)
      end

      def to_h
        {
          event_type: event_type,
          order_id: order_id,
          operation_id: operation_id,
          subscription_id: subscription_id,
          status: status,
          reason: reason,
          data: data
        }
      end

      private

      def parse_notification
        payload = @data['payload'] || @data
        
        @order_id = payload['order_id'] || payload.dig('order', 'id')
        @operation_id = payload['operation_id'] || payload.dig('operation', 'id')
        @subscription_id = payload['subscription_id'] || payload.dig('subscription', 'id')
        @status = payload['status'] || payload.dig('order', 'status') || 
                  payload.dig('operation', 'status')
        @reason = payload['reason'] || payload['reason_code']
      end

      def compute_signature(secret_key)
        body = @raw_data.is_a?(String) ? @raw_data : JSON.fast_generate(@raw_data)
        digest = OpenSSL::Digest.new(DEFAULT_ALGORITHM)
        OpenSSL::HMAC.hexdigest(digest, secret_key, body)
      end

      # Constant-time string comparison to prevent timing attacks
      def secure_compare(a, b)
        return false if a.nil? || b.nil? || a.bytesize != b.bytesize

        l = a.unpack("C*")
        r = 0
        i = -1
        b.each_byte { |v| r |= v ^ l[i += 1] }
        r == 0
      end
    end
  end
end

