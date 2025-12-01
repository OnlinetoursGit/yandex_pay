# frozen_string_literal: true

module Yandex
  module Pay
    # Yandex::Pay::Resource
    class Resource
      def initialize(client:)
        @client = client
      end

      def basic_path
        '/api/merchant/v1'
      end
    end
  end
end

