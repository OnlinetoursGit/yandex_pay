# frozen_string_literal: true

module Yandex
  module Pay
    # Yandex::Pay::Order
    # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/
    class Order < Resource
      # Create a new order
      # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders
      # @param params [Hash] order parameters
      # @return [Hash] API response
      def create(params: {})
        @client.post(endpoint: "#{basic_path}/orders",
                     payload: JSON.fast_generate(params))
      end

      # Get order details by ID
      # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id
      # @param order_id [String] order identifier
      # @return [Hash] API response
      def get(order_id:)
        @client.get(endpoint: "#{basic_path}/orders/#{order_id}")
      end

      # Cancel an order
      # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id-cancel
      # @param order_id [String] order identifier
      # @param params [Hash] cancellation parameters
      # @return [Hash] API response
      def cancel(order_id:, params: {})
        @client.post(endpoint: "#{basic_path}/orders/#{order_id}/cancel",
                     payload: JSON.fast_generate(params))
      end

      # Capture payment for an order (confirm the payment)
      # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id-capture
      # @param order_id [String] order identifier
      # @param params [Hash] capture parameters
      # @return [Hash] API response
      def capture(order_id:, params: {})
        @client.post(endpoint: "#{basic_path}/orders/#{order_id}/capture",
                     payload: JSON.fast_generate(params))
      end

      # Submit order
      # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id-submit
      # @param order_id [String] order identifier
      # @param params [Hash] submit parameters
      # @return [Hash] API response
      def submit(order_id:, params: {})
        @client.post(endpoint: "#{basic_path}/orders/#{order_id}/submit",
                     payload: JSON.fast_generate(params))
      end

      # Rollback an order
      # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id-rollback
      # @param order_id [String] order identifier
      # @param params [Hash] rollback parameters
      # @return [Hash] API response
      def rollback(order_id:, params: {})
        @client.post(endpoint: "#{basic_path}/orders/#{order_id}/rollback",
                     payload: JSON.fast_generate(params))
      end
    end
  end
end

