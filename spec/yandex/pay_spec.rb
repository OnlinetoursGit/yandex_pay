# frozen_string_literal: true

RSpec.describe Yandex::Pay do
  it 'has a version number' do
    expect(Yandex::Pay::VERSION).not_to be nil
  end

  describe Yandex::Pay::Api do
    let(:api_key) { 'test-api-key' }
    let(:api) { described_class.new(api_key: api_key) }

    describe '#initialize' do
      it 'creates an API instance with resources' do
        expect(api.resources.orders).to be_a(Yandex::Pay::Order)
        expect(api.resources.refunds).to be_a(Yandex::Pay::Refund)
        expect(api.resources.operations).to be_a(Yandex::Pay::Operation)
        expect(api.resources.subscriptions).to be_a(Yandex::Pay::Subscription)
      end

      it 'uses production host by default' do
        expect(api.client.instance_variable_get(:@host)).to eq('https://pay.yandex.ru')
      end

      it 'uses sandbox host when environment is sandbox' do
        sandbox_api = described_class.new(api_key: api_key, environment: :sandbox)
        expect(sandbox_api.client.instance_variable_get(:@host)).to eq('https://sandbox.pay.yandex.ru')
      end

      it 'allows custom host' do
        custom_api = described_class.new(api_key: api_key, host: 'https://custom.host')
        expect(custom_api.client.instance_variable_get(:@host)).to eq('https://custom.host')
      end
    end
  end

  describe Yandex::Pay::Order do
    let(:api_key) { 'test-api-key' }
    let(:stubs) { Faraday::Adapter::Test::Stubs.new }
    let(:test_connection) do
      Faraday.new('https://pay.yandex.ru') do |builder|
        builder.adapter :test, stubs
      end
    end
    let(:client) { Yandex::Pay::ApiClient.new(api_key: api_key, host: 'https://pay.yandex.ru') }
    let(:orders) { Yandex::Pay::Order.new(client: client) }

    before do
      allow(client).to receive(:connection).and_return(test_connection)
    end

    describe '#create' do
      let(:order_params) do
        {
          cart: {
            items: [{ productId: 'p1', title: 'Test', unitPrice: '100.00', total: '100.00' }],
            total: { amount: '100.00' }
          },
          currencyCode: 'RUB',
          orderId: 'order-123'
        }
      end

      it 'creates an order' do
        stubs.post('/api/merchant/v1/orders') do
          [200, { 'Content-Type' => 'application/json' },
           '{"data":{"orderId":"order-123","status":"CREATED"}}']
        end

        response = orders.create(params: order_params)
        expect(response['data']['orderId']).to eq('order-123')
      end
    end

    describe '#get' do
      it 'gets order details' do
        stubs.get('/api/merchant/v1/orders/order-123') do
          [200, { 'Content-Type' => 'application/json' },
           '{"data":{"orderId":"order-123","status":"CAPTURED"}}']
        end

        response = orders.get(order_id: 'order-123')
        expect(response['data']['status']).to eq('CAPTURED')
      end
    end

    describe '#cancel' do
      it 'cancels an order' do
        stubs.post('/api/merchant/v1/orders/order-123/cancel') do
          [200, { 'Content-Type' => 'application/json' },
           '{"data":{"orderId":"order-123","status":"CANCELLED"}}']
        end

        response = orders.cancel(order_id: 'order-123', params: { reason: 'Test' })
        expect(response['data']['status']).to eq('CANCELLED')
      end
    end

    describe '#capture' do
      it 'captures payment for an order' do
        stubs.post('/api/merchant/v1/orders/order-123/capture') do
          [200, { 'Content-Type' => 'application/json' },
           '{"data":{"orderId":"order-123","status":"CAPTURED"}}']
        end

        response = orders.capture(order_id: 'order-123')
        expect(response['data']['status']).to eq('CAPTURED')
      end
    end
  end

  describe Yandex::Pay::Notification do
    let(:notification_data) do
      {
        "event": "ORDER_STATUS_UPDATED",
        "event_time": "2025-12-10T15:19:07.599093+00:00",
        "merchant_id": "040d2366-16f3-4b8d-948c-0c27c5f4df31",
        "order": {
          "order_id": "order-123",
          "payment_status": "CAPTURED"
        }
      }
    end

    describe '#initialize' do
      it 'parses notification data' do
        notification = described_class.new(data: notification_data)
        expect(notification.event_type).to eq('ORDER_STATUS_UPDATED')
        expect(notification.order_id).to eq('order-123')
        expect(notification.status).to eq('CAPTURED')
      end

      it 'raises error for unsupported event type' do
        invalid_data = { 'event' => 'UNKNOWN_EVENT' }
        expect { described_class.new(data: invalid_data) }
          .to raise_error(Yandex::Pay::Notification::UnsupportedTypeError)
      end
    end

    describe '#success?' do
      it 'returns true for SUCCESS status' do
        data = notification_data.merge('payload' => { 'status' => 'SUCCESS' })
        notification = described_class.new(data: data)
        expect(notification.success?).to be true
      end

      it 'returns true for CAPTURED status' do
        notification = described_class.new(data: notification_data)
        expect(notification.success?).to be true
      end
    end
  end
end
