# frozen_string_literal: true

# Helper for stubbing Faraday connections using Faraday::Adapter::Test
# module FaradayTestHelpers
#   def stub_faraday_connection
#     stubs = Faraday::Adapter::Test::Stubs.new
#     connection = Faraday.new do |builder|
#       builder.adapter :test, stubs
#     end
#     [stubs, connection]
#   end
# end

# RSpec.configure do |config|
#   config.include FaradayTestHelpers
# end
