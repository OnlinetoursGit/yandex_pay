# frozen_string_literal: true

module Yandex
  module Pay
    # Yandex::Pay::ApiClient
    class ApiClient
      # https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/
      # Максимальное значение таймаута — 10 секунд.
      TIMEOUT = 10

      def initialize(api_key:, host:)
        @default_headers = {
          'Content-Type': 'application/json;charset=UTF-8',
          Accept: 'application/json',
          Authorization: "Api-Key #{api_key}"
        }
        @host = host
      end

      def get(endpoint:, custom_headers: {})
        make_request do
          connection.get(endpoint, {}, @default_headers.merge(custom_headers))
        end
      end

      def post(endpoint:, payload: nil, custom_headers: {})
        make_request do
          connection.post(endpoint, payload, @default_headers.merge(custom_headers))
        end
      end

      def put(endpoint:, payload: nil, custom_headers: {})
        make_request do
          connection.put(endpoint, payload, @default_headers.merge(custom_headers))
        end
      end

      def delete(endpoint:, custom_headers: {})
        make_request do
          connection.delete(endpoint, {}, @default_headers.merge(custom_headers))
        end
      end

      def connection
        @connection ||= Faraday::Connection.new(@host) do |c|
          c.options.timeout = TIMEOUT
        end
      end

      private

      def make_request
        response = yield
        JSON.parse(response.body)
      rescue StandardError => e
        raise ApiException, e.message
      end

      def with_retries(retries_count = 5, timeout = 5)
        retries_count -= 1
        response = yield
        JSON.parse(response.body)
      rescue StandardError => e
        raise ApiException, "Message: #{e.message}. Number of connection tries exceed." unless retries_count.positive?

        sleep(timeout)
        retry
      end
    end
  end
end

