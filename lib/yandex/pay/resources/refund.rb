# frozen_string_literal: true

module Yandex
  module Pay
    # Yandex::Pay::Refund
    # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/
    class Refund < Resource
      # Create a refund for an order (v2)
      # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v2-orders-order_id-refund
      # @param order_id [String] order identifier
      # @param params [Hash] refund parameters
      # @return [Hash] API response
      def create(order_id:, params: {})
        @client.post(endpoint: "/api/merchant/v2/orders/#{order_id}/refund",
                     payload: JSON.fast_generate(params))
      end
    end
  end
end

