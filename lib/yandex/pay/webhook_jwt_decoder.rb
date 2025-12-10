# frozen_string_literal: true

require 'jwt'
require 'net/http'
require 'json'

module Yandex
  module Pay
    # Decodes and verifies JWT tokens from Yandex Pay webhooks
    #
    # The JWT token is signed with ES256 algorithm using Yandex Pay's private key.
    # Public keys for verification can be fetched from Yandex Pay JWKS endpoint.
    #
    # @see https://pay.yandex.ru/docs/ru/custom/backend/merchant-api/webhook
    #
    # @example Decode without verification (for testing)
    #   decoder = Yandex::Pay::WebhookJwtDecoder.new(raw_token, verify: false)
    #   payload = decoder.decode
    #   notification = decoder.to_notification
    #
    # @example Decode with verification
    #   decoder = Yandex::Pay::WebhookJwtDecoder.new(raw_token)
    #   payload = decoder.decode
    class WebhookJwtDecoder
      class DecodeError < StandardError; end
      class TokenExpiredError < DecodeError; end
      class InvalidSignatureError < DecodeError; end
      class InvalidTokenError < DecodeError; end
      class JwksError < DecodeError; end

      # JWKS endpoint for fetching public keys
      PRODUCTION_JWKS_URL = 'https://pay.yandex.ru/api/jwks'
      SANDBOX_JWKS_URL = 'https://sandbox.pay.yandex.ru/api/jwks'

      # Cache JWKS for 1 hour
      JWKS_CACHE_TTL = 3600

      attr_reader :raw_token, :options

      class << self
        # Clear JWKS cache (useful for testing or when keys are rotated)
        def clear_jwks_cache!
          @jwks_cache = nil
          @jwks_cache_time = nil
        end

        attr_accessor :jwks_cache, :jwks_cache_time
      end

      # @param raw_token [String] JWT token from webhook body
      # @param options [Hash] Options for decoding
      # @option options [Boolean] :verify (true) Whether to verify the token signature
      # @option options [Boolean] :verify_expiration (true) Whether to verify expiration
      # @option options [Symbol] :environment (:production) :production or :sandbox
      def initialize(raw_token, options = {})
        @raw_token = raw_token&.strip
        @options = {
          verify: true,
          verify_expiration: true,
          environment: :production
        }.merge(options)
      end

      # Decodes and optionally verifies the JWT token
      # @return [Hash] Decoded payload
      # @raise [DecodeError] if decoding fails
      def decode
        raise InvalidTokenError, 'Token is blank' if raw_token.nil? || raw_token.empty?

        if options[:verify]
          decode_with_verification
        else
          decode_without_verification
        end
      rescue JWT::ExpiredSignature => e
        raise TokenExpiredError, "Token expired: #{e.message}"
      rescue JWT::VerificationError => e
        raise InvalidSignatureError, "Invalid signature: #{e.message}"
      rescue JWT::DecodeError => e
        raise InvalidTokenError, "Invalid token: #{e.message}"
      end

      # Decodes the token and returns a Notification object
      # @return [Yandex::Pay::Notification]
      def to_notification
        Notification.new(data: decode)
      end

      # Get token header without verification
      # @return [Hash] Token header
      def header
        @header ||= begin
          parts = raw_token.split('.')
          raise InvalidTokenError, 'Invalid token format' if parts.length < 2

          JSON.parse(Base64.urlsafe_decode64(parts[0]))
        rescue JSON::ParserError, ArgumentError => e
          raise InvalidTokenError, "Failed to parse token header: #{e.message}"
        end
      end

      # Get key ID from token header
      # @return [String, nil]
      def kid
        header['kid']
      end

      private

      def decode_without_verification
        payload, _header = JWT.decode(raw_token, nil, false)
        symbolize_keys(payload)
      end

      def decode_with_verification
        public_key = fetch_public_key(kid)

        payload, _header = JWT.decode(
          raw_token,
          public_key,
          true,
          {
            algorithm: 'ES256',
            verify_expiration: options[:verify_expiration]
          }
        )

        symbolize_keys(payload)
      end

      def fetch_public_key(key_id)
        jwks = fetch_jwks
        jwk = jwks.find { |key| key['kid'] == key_id }

        raise InvalidTokenError, "Public key not found for kid: #{key_id}" unless jwk

        JWT::JWK.import(jwk).public_key
      end

      def fetch_jwks
        # Check cache first
        if cached_jwks_valid?
          return self.class.jwks_cache
        end

        response = make_jwks_request
        keys = parse_jwks_response(response)

        # Cache the result
        self.class.jwks_cache = keys
        self.class.jwks_cache_time = Time.now

        keys
      end

      def cached_jwks_valid?
        return false unless self.class.jwks_cache && self.class.jwks_cache_time

        (Time.now - self.class.jwks_cache_time) < JWKS_CACHE_TTL
      end

      def make_jwks_request
        uri = URI(jwks_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 10

        request = Net::HTTP::Get.new(uri)
        request['Accept'] = 'application/json'

        http.request(request)
      rescue StandardError => e
        raise JwksError, "Failed to fetch JWKS: #{e.message}"
      end

      def parse_jwks_response(response)
        unless response.is_a?(Net::HTTPSuccess)
          raise JwksError, "JWKS request failed with status #{response.code}"
        end

        data = JSON.parse(response.body)
        keys = data['keys']

        raise JwksError, 'No keys found in JWKS response' if keys.nil? || keys.empty?

        keys
      rescue JSON::ParserError => e
        raise JwksError, "Failed to parse JWKS response: #{e.message}"
      end

      def jwks_url
        options[:environment] == :sandbox ? SANDBOX_JWKS_URL : PRODUCTION_JWKS_URL
      end

      def symbolize_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.each_with_object({}) do |(key, value), result|
          sym_key = key.to_sym
          result[sym_key] = value.is_a?(Hash) ? symbolize_keys(value) : value
        end
      end
    end
  end
end

