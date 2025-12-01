# frozen_string_literal: true

module Yandex
  module Pay
    # Yandex::Pay::Subscription
    # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/subscriptions/
    class Subscription < Resource
      # Get subscription details by ID
      # @param subscription_id [String] subscription identifier
      # @return [Hash] API response
      def get(subscription_id:)
        @client.get(endpoint: "#{basic_path}/subscriptions/#{subscription_id}")
      end

      # Cancel a subscription
      # @param subscription_id [String] subscription identifier
      # @param params [Hash] cancellation parameters
      # @return [Hash] API response
      def cancel(subscription_id:, params: {})
        @client.post(endpoint: "#{basic_path}/subscriptions/#{subscription_id}/cancel",
                     payload: JSON.fast_generate(params))
      end
    end
  end
end

