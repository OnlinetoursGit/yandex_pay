# frozen_string_literal: true

require 'ostruct'
require 'faraday'
require 'json'
require 'yandex/pay/api_client'
require 'yandex/pay/utils'
require 'yandex/pay/notification'
require 'yandex/pay/resource'
require 'yandex/pay/version'

Gem.find_files('yandex/pay/resources/*.rb').each { |path| require path }

module Yandex
  module Pay
    class ApiException < StandardError; end

    API_HOSTS = {
      production: 'https://pay.yandex.ru',
      sandbox: 'https://sandbox.pay.yandex.ru'
    }.freeze

    # Yandex::Pay::Api
    class Api
      attr_reader :client, :resources

      # Initialize the API client
      # @param api_key [String] your Yandex Pay API key
      # @param environment [Symbol] :production or :sandbox (default: :production)
      # @param host [String, nil] custom API host (optional, overrides environment)
      def initialize(api_key:, environment: :production, host: nil)
        actual_host = host || API_HOSTS[environment] || API_HOSTS[:production]

        @client = Yandex::Pay::ApiClient.new(api_key: api_key, host: actual_host)
        @resources = OpenStruct.new(
          orders: Yandex::Pay::Order.new(client: @client),
          refunds: Yandex::Pay::Refund.new(client: @client),
          operations: Yandex::Pay::Operation.new(client: @client),
          subscriptions: Yandex::Pay::Subscription.new(client: @client)
        )
      end
    end
  end
end

