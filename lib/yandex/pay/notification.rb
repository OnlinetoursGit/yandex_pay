# frozen_string_literal: true

require 'openssl'

module Yandex
  module Pay
    # Yandex::Pay::Notification
    # Handles webhook notifications from Yandex Pay Merchant API
    #
    # Supports both new webhook format (JWT-based) and legacy format for backward compatibility.
    #
    # @see https://pay.yandex.ru/docs/ru/custom/backend/merchant-api/webhook
    #
    # @example New webhook format (from JWT payload)
    #   notification = Yandex::Pay::Notification.new(data: jwt_payload)
    #   notification.event_type # => "OPERATION_STATUS_UPDATED"
    #   notification.operation_type # => "CAPTURE"
    #   notification.success? # => true
    #
    # @example Legacy format (for backward compatibility)
    #   notification = Yandex::Pay::Notification.new(data: legacy_params)
    #   notification.success? # => true
    class Notification
      class UnsupportedTypeError < StandardError; end

      DEFAULT_ALGORITHM = 'sha256'

      # Supported event types from Yandex Pay webhook
      SUPPORTED_EVENT_TYPES = %w[
        ORDER_STATUS_UPDATED
        OPERATION_STATUS_UPDATED
        SUBSCRIPTION_STATUS_UPDATED
        REFUND_STATUS_UPDATED
      ].freeze

      # Operation statuses
      OPERATION_SUCCESS_STATUS = 'SUCCESS'
      OPERATION_FAIL_STATUS = 'FAIL'
      OPERATION_PENDING_STATUS = 'PENDING'

      # Payment statuses for orders
      ORDER_SUCCESS_STATUSES = %w[AUTHORIZED CAPTURED CONFIRMED PARTIALLY_REFUNDED REFUNDED VOIDED].freeze
      ORDER_FAILURE_STATUSES = %w[FAILED].freeze
      ORDER_PENDING_STATUS = 'PENDING'

      # Operation types
      OPERATION_TYPES = %w[AUTHORIZE BIND_CARD REFUND CAPTURE VOID RECURRING PREPAYMENT SUBMIT].freeze

      attr_reader :data, :raw_data

      def initialize(data:)
        @raw_data = data
        @data = normalize_data(data)
        validate_event_type! unless legacy_format?
      end

      # @return [String, nil] Event type: "ORDER_STATUS_UPDATED" or "OPERATION_STATUS_UPDATED"
      def event_type
        @data[:event]
      end

      # Alias for event_type
      alias event event_type

      # @return [String, nil] Event time in RFC 3339 format
      def event_time
        @data[:event_time]
      end

      # @return [String, nil] Merchant ID (UUID)
      def merchant_id
        @data[:merchant_id]
      end

      # @return [Hash, nil] Operation data from webhook
      def operation_data
        @data[:operation]
      end

      # @return [Hash, nil] Order data from webhook
      def order_data
        @data[:order]
      end

      # @return [Hash, nil] Subscription data from webhook
      def subscription_data
        @data[:subscription]
      end

      # @return [Boolean] true if this is an operation status update event
      def operation_status_updated?
        event_type == 'OPERATION_STATUS_UPDATED'
      end

      # @return [Boolean] true if this is an order status update event
      def order_status_updated?
        event_type == 'ORDER_STATUS_UPDATED'
      end

      # @return [Boolean] true if this is a subscription status update event
      def subscription_status_updated?
        event_type == 'SUBSCRIPTION_STATUS_UPDATED'
      end

      # Order ID - this is the payment_id from our system sent during order creation
      # @return [String, nil]
      def order_id
        operation_data&.dig(:order_id) || order_data&.dig(:order_id) || @data[:order_id]
      end

      # Operation ID (UUID) from Yandex Pay
      # @return [String, nil]
      def operation_id
        operation_data&.dig(:operation_id) || @data[:operation_id]
      end

      # External operation ID - our system's operation ID passed during operation creation
      # @return [String, nil]
      def external_operation_id
        operation_data&.dig(:external_operation_id)
      end

      # Operation type: AUTHORIZE, CAPTURE, VOID, REFUND, RECURRING, etc.
      # @return [String, nil]
      def operation_type
        operation_data&.dig(:operation_type)
      end

      # Operation status: PENDING, SUCCESS, FAIL
      # @return [String, nil]
      def operation_status
        operation_data&.dig(:status)
      end

      # Payment status from order data
      # @return [String, nil] PENDING, AUTHORIZED, CAPTURED, VOIDED, REFUNDED, CONFIRMED, PARTIALLY_REFUNDED, FAILED
      def payment_status
        order_data&.dig(:payment_status)
      end

      # Whether the cart was updated (for points payments)
      # @return [Boolean, nil]
      def cart_updated?
        order_data&.dig(:cart_updated)
      end

      # Subscription ID
      # @return [String, nil]
      def subscription_id
        subscription_data&.dig(:customer_subscription_id)
      end

      # Subscription status
      # @return [String, nil]
      def subscription_status
        subscription_data&.dig(:status)
      end

      # @return [Boolean] true if the notification indicates success
      def success?
        return legacy_success? if legacy_format?

        if operation_status_updated?
          operation_status == OPERATION_SUCCESS_STATUS
        elsif order_status_updated?
          ORDER_SUCCESS_STATUSES.include?(payment_status)
        elsif subscription_status_updated?
          subscription_status == 'ACTIVE'
        else
          false
        end
      end

      # @return [Boolean] true if the notification indicates failure
      def failed?
        return legacy_failed? if legacy_format?

        if operation_status_updated?
          operation_status == OPERATION_FAIL_STATUS
        elsif order_status_updated?
          ORDER_FAILURE_STATUSES.include?(payment_status)
        elsif subscription_status_updated?
          %w[CANCELLED EXPIRED].include?(subscription_status)
        else
          false
        end
      end

      # @return [Boolean] true if the notification indicates pending state
      def pending?
        return legacy_pending? if legacy_format?

        if operation_status_updated?
          operation_status == OPERATION_PENDING_STATUS
        elsif order_status_updated?
          payment_status == ORDER_PENDING_STATUS
        elsif subscription_status_updated?
          subscription_status == 'NEW'
        else
          false
        end
      end

      # Reason code for failures
      # @return [String, nil]
      def reason
        @data[:reason] || @data[:reason_code]
      end

      # Combined status accessor
      # @return [String, nil]
      def status
        return @data[:status] if legacy_format?

        operation_status || payment_status || subscription_status
      end

      # Validate webhook signature using HMAC
      # @param secret_key [String] webhook secret key
      # @param signature [String] signature from request header
      # @return [Boolean]
      def valid_signature?(secret_key:, signature:)
        return false if signature.nil? || signature.empty?

        expected_signature = compute_signature(secret_key)
        secure_compare(signature, expected_signature)
      end

      # Alias for backward compatibility
      alias valid? valid_signature?

      # @return [Hash] Full notification data
      def to_h
        @data
      end

      # ========================================
      # Legacy format compatibility methods
      # These methods support old Sberbank-style notifications
      # ========================================

      # @return [Boolean] true if this is a legacy format notification
      def legacy_format?
        @data.key?(:checksum) || @data.key?(:md_order) || @data.key?(:authorize_id)
      end

      # Legacy operation field (approved, deposited, declinedByTimeout, etc.)
      # @return [String, nil]
      def operation
        return @data[:operation] if legacy_format?

        operation_type&.downcase
      end

      # Legacy amount field (in kopecks)
      # @return [String, nil]
      def amount
        @data[:amount]
      end

      # Legacy payment ID
      # @return [String, nil]
      def payment_id
        @data[:payment_id]
      end

      # Legacy authorize ID
      # @return [String, nil]
      def authorize_id
        @data[:authorize_id]
      end

      # Legacy capture ID
      # @return [String, nil]
      def capture_id
        @data[:capture_id]
      end

      # Legacy refund ID
      # @return [String, nil]
      def refund_id
        @data[:refund_id]
      end

      # Legacy cancel ID
      # @return [String, nil]
      def cancel_id
        @data[:cancel_id]
      end

      # Legacy mdOrder field
      # @return [String, nil]
      def md_order
        @data[:md_order]
      end

      private

      def normalize_data(data)
        normalized = Utils.deep_transform_keys(data) { |k| Utils.snake_case(k.to_s).to_sym }
        normalized.is_a?(Hash) ? normalized : {}
      end

      def validate_event_type!
        return if event_type.nil? # Allow nil for backward compatibility

        unless SUPPORTED_EVENT_TYPES.include?(event_type)
          raise UnsupportedTypeError, "Unsupported notification type: #{event_type}."
        end
      end

      # Legacy success check (old Sberbank format)
      def legacy_success?
        @data[:status].to_s == '1' && @data[:operation] != 'declinedByTimeout'
      end

      # Legacy failure check
      def legacy_failed?
        @data[:status].to_s == '0' || @data[:operation] == 'declinedByTimeout'
      end

      # Legacy pending check
      def legacy_pending?
        !legacy_success? && !legacy_failed?
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

