# frozen_string_literal: true

module Yandex
  module Pay
    # Yandex::Pay::Operation
    # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/operation/
    class Operation < Resource
      # Get operation details by ID
      # @param operation_id [String] operation identifier
      # @return [Hash] API response
      def get(operation_id:)
        @client.get(endpoint: "#{basic_path}/operations/#{operation_id}")
      end

      # List operations
      # @param params [Hash] query parameters (order_id, etc.)
      # @return [Hash] API response
      def list(params: {})
        query = params.empty? ? '' : "?#{Faraday::Utils.build_query(params)}"
        @client.get(endpoint: "#{basic_path}/operations#{query}")
      end
    end
  end
end

