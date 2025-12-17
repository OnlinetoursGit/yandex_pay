# frozen_string_literal: true

require 'openssl'

module Yandex
  module Pay
    # Yandex::Pay::Notification
    # Handles webhook notifications from Yandex Pay Merchant API
    #
    # Supports webhook format (JWT-based)
    #
    # @see https://pay.yandex.ru/docs/ru/custom/backend/merchant-api/webhook
    #
    # @example New webhook format (from JWT payload)
    #   notification = Yandex::Pay::Notification.new(data: jwt_payload)
    #   notification.event_type # => "OPERATION_STATUS_UPDATED"
    #   notification.operation_type # => "CAPTURE"
    #   notification.success? # => true
    class Notification
      class UnsupportedTypeError < StandardError; end

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
        validate_event_type!
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
        operation_status || payment_status || subscription_status
      end

      # @return [Hash] Full notification data
      def to_h
        @data
      end

      # @return [String, nil]
      def operation
        operation_type&.downcase
      end

      private

      def normalize_data(data)
        normalized = Utils.deep_transform_keys(data) { |k| Utils.snake_case(k.to_s).to_sym }
        normalized.is_a?(Hash) ? normalized : {}
      end

      def validate_event_type!
        unless SUPPORTED_EVENT_TYPES.include?(event_type)
          raise UnsupportedTypeError, "Unsupported notification type: #{event_type}."
        end
      end
    end
  end
end

