# Yandex::Pay

Ruby wrapper to interact with [Yandex Pay API](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/).

To experiment with that code, run `bin/console` for an interactive prompt.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yandex_pay'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install yandex_pay

## Usage

### Interact with API

#### Initialize `api` object:

```ruby
api = Yandex::Pay::Api.new(api_key: "your-api-key")
```

For sandbox environment:

```ruby
api = Yandex::Pay::Api.new(api_key: "your-api-key", environment: :sandbox)
```

Optional param `host` for custom API host:

```ruby
api = Yandex::Pay::Api.new(api_key: "your-api-key", host: "https://custom.api.host")
```

Default hosts:
- `https://pay.yandex.ru` for production
- `https://sandbox.pay.yandex.ru` for sandbox

### Orders

#### Create order ([api doc](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders)):

```ruby
api.resources.orders.create(params: {
  cart: {
    items: [
      {
        productId: "product-1",
        quantity: { count: "1" },
        title: "Product name",
        unitPrice: "1000.00",
        subtotal: "1000.00",
        total: "1000.00"
      }
    ],
    total: { amount: "1000.00" }
  },
  currencyCode: "RUB",
  orderId: "order-123",
  redirectUrls: {
    onSuccess: "https://your-site.com/success",
    onError: "https://your-site.com/error"
  }
})
```

#### Get order details ([api doc](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id)):

```ruby
api.resources.orders.get(order_id: "order-123")
```

#### Cancel order ([api doc](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id-cancel)):

```ruby
api.resources.orders.cancel(order_id: "order-123", params: { reason: "Customer request" })
```

#### Capture payment ([api doc](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id-capture)):

```ruby
api.resources.orders.capture(order_id: "order-123", params: {})
```

#### Submit order ([api doc](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id-submit)):

```ruby
api.resources.orders.submit(order_id: "order-123", params: {})
```

#### Rollback order ([api doc](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v1-orders-order_id-rollback)):

```ruby
api.resources.orders.rollback(order_id: "order-123", params: {})
```

### Refunds

#### Create refund (v2) ([api doc](https://pay.yandex.ru/docs/ru/custom/backend/yandex-pay-api/order/v2-orders-order_id-refund)):

```ruby
api.resources.refunds.create(order_id: "order-123", params: {
  refundAmount: "500.00",
  reason: "Customer request"
})
```

### Operations

#### Get operation details:

```ruby
api.resources.operations.get(operation_id: "operation-123")
```

#### List operations:

```ruby
api.resources.operations.list(params: { order_id: "order-123" })
```

### Subscriptions

#### Get subscription details:

```ruby
api.resources.subscriptions.get(subscription_id: "subscription-123")
```

#### Cancel subscription:

```ruby
api.resources.subscriptions.cancel(subscription_id: "subscription-123", params: {})
```

### Server Notifications (Webhooks)

#### Build notification inside your callback controller:

```ruby
notification = Yandex::Pay::Notification.new(data: notification_params)
```

#### Check if notification is valid:

```ruby
notification.valid?(secret_key: webhook_secret_key, signature: request.headers["X-Signature"])
```

#### Check notification status:

```ruby
notification.success?  # => true/false
notification.pending?  # => true/false
notification.failed?   # => true/false
```

#### Get notification data:

```ruby
notification.event_type    # => "ORDER_STATUS_UPDATED"
notification.order_id      # => "order-123"
notification.status        # => "CAPTURED"
notification.to_h          # => { event_type: ..., order_id: ..., ... }
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Run tests

```bash
bundle exec rake spec
```

## Contributing

Bug reports and pull requests are welcome on GitHub. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Yandex::Pay project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/OnlinetoursGit/yandex_pay/blob/master/CODE_OF_CONDUCT.md).
