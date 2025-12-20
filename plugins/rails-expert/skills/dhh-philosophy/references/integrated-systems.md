# Integrated Systems: Rails' Architectural Philosophy

## Introduction

Rails champions the integrated system—a unified application where components share code, data, and process space. This philosophy stands in contrast to the distributed systems trend that fragments applications into independent services communicating over networks.

DHH and the Rails core team believe that most applications don't need the complexity of distributed architectures. An integrated system offers simplicity, reliability, and developer productivity that fragmented systems cannot match.

## What is an Integrated System?

An integrated system is characterized by:

- **Single codebase**: All application code lives in one repository
- **Shared database**: Components access the same database directly
- **In-process communication**: Components call each other as Ruby methods, not HTTP requests
- **Unified deployment**: The entire application deploys as one unit
- **Shared resources**: Memory, cache, and connections are shared efficiently

This differs fundamentally from distributed systems where:

- Multiple repositories hold separate services
- Each service has its own database (or schema)
- Services communicate via HTTP, gRPC, or message queues
- Each service deploys independently
- Resources are isolated and duplicated

## Benefits of Integration

### Transactional Integrity

Integrated systems make transactions trivial:

```ruby
ActiveRecord::Base.transaction do
  order = Order.create!(user: current_user, total: cart.total)
  cart.line_items.each do |item|
    order.line_items.create!(product: item.product, quantity: item.quantity)
    item.product.decrement!(:stock, item.quantity)
  end
  Payment.create!(order: order, amount: order.total, status: :pending)
end
```

All operations succeed or fail together. No distributed transaction coordination. No saga patterns. No compensating transactions.

In distributed systems, this simple operation requires:

- Two-phase commit protocols (complex, slow)
- Saga patterns with compensating actions (error-prone)
- Eventual consistency acceptance (confusing for users)
- Idempotency keys everywhere (boilerplate)

### Simplified Debugging

When something goes wrong in an integrated system:

```ruby
# Stack trace shows complete flow
OrdersController#create
  Order.create!
    OrderMailer.confirmation
    InventoryService.reserve
      Product.decrement!
```

You can:

- Set breakpoints anywhere in the call chain
- Inspect all state in one process
- See complete logs in one place
- Step through code with a debugger
- Reproduce issues locally with one application

In distributed systems:

- Traces span multiple services
- Logs are scattered across systems
- Correlation IDs must be threaded everywhere
- Network issues mask root causes
- Local reproduction requires running multiple services

### Faster Development

Adding a feature in an integrated system:

1. Write migration
2. Add model logic
3. Update controller
4. Create view
5. Write tests
6. Deploy

Adding a feature across distributed services:

1. Decide which services need changes
2. Update each service's schema (coordinate migrations)
3. Update service APIs (version them)
4. Update API clients in consuming services
5. Write tests in each service
6. Deploy services in correct order
7. Monitor for distributed failures

One approach takes hours. The other takes days or weeks.

### Lower Operational Complexity

Integrated system operations:

- One application to monitor
- One database to backup
- One deployment to manage
- One set of logs to aggregate
- One performance profile to optimize

Distributed system operations:

- Multiple services to monitor (each with different patterns)
- Multiple databases to backup and sync
- Coordinated deployments with rollback planning
- Distributed logging and tracing infrastructure
- Complex performance profiling across network boundaries

### Efficient Resource Usage

Integrated systems share:

- Database connection pools
- Memory for cached objects
- CPU for background processing
- Network connections to external services

Distributed systems duplicate:

- Connection pools per service (often oversized)
- Memory for serialized data transfer
- CPU for marshaling/unmarshaling
- Network overhead for inter-service calls

## Rails Tools for Integration

Rails provides powerful tools for organizing integrated systems without fragmenting them.

### Namespaces

Organize code by domain without network boundaries:

```ruby
# app/models/checkout/cart.rb
module Checkout
  class Cart < ApplicationRecord
    belongs_to :user
    has_many :line_items
  end
end

# app/models/inventory/product.rb
module Inventory
  class Product < ApplicationRecord
    has_many :line_items, class_name: 'Checkout::LineItem'
  end
end
```

Clear boundaries. Direct method calls. Shared database.

### Concerns

Extract shared behavior without duplication:

```ruby
# app/models/concerns/trackable.rb
module Trackable
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :trackable
    after_create :track_creation
  end

  def track_creation
    events.create!(action: 'created', user: Current.user)
  end
end

# Used across multiple models
class Order < ApplicationRecord
  include Trackable
end

class Product < ApplicationRecord
  include Trackable
end
```

### Engines

For truly large applications, Rails Engines provide isolation:

```ruby
# engines/checkout/lib/checkout.rb
module Checkout
  class Engine < ::Rails::Engine
    isolate_namespace Checkout
  end
end
```

Engines have their own:

- Models and controllers
- Routes and views
- Migrations and tests

But share:

- Database and transactions
- Process space and memory
- Deployment and operations

Engines give you service-like boundaries without the distributed systems tax.

### Service Objects

Encapsulate complex operations without network calls:

```ruby
# app/services/orders/placement_service.rb
module Orders
  class PlacementService
    def initialize(cart, user)
      @cart = cart
      @user = user
    end

    def call
      ActiveRecord::Base.transaction do
        create_order
        reserve_inventory
        charge_payment
        send_confirmation
      end
    end

    private

    # All methods are direct Ruby calls
    def create_order
      @order = Order.create!(user: @user, total: @cart.total)
    end

    def reserve_inventory
      @cart.line_items.each do |item|
        item.product.decrement!(:stock, item.quantity)
      end
    end

    def charge_payment
      PaymentGateway.charge(@user.payment_method, @order.total)
    end

    def send_confirmation
      OrderMailer.confirmation(@order).deliver_later
    end
  end
end
```

Clear organization. Full transactional safety. Simple debugging.

## The Solid Suite: Integration Applied to Infrastructure

Rails 8's Solid gems embody integrated systems philosophy applied to infrastructure. See `solid-suite.md` for details.

Traditional stacks fragment infrastructure:

- Application server (Rails)
- Cache server (Redis)
- Job processor (Sidekiq + Redis)
- WebSocket pub/sub (Redis)

Solid Stack integrates everything:

- Application server (Rails)
- Database (PostgreSQL/MySQL) handles cache, jobs, and pub/sub

Fewer moving parts. Simpler operations. Same reliability.

## When to Distribute

Integration isn't dogma. Distribute when you have specific, unavoidable needs:

### Genuine Scale Requirements

If one component has radically different scaling needs:

```text
Main app: 100 requests/second
Video processing: Spiky, GPU-intensive, needs horizontal scaling

Solution: Extract video processing as separate service
```

### Team Independence

If teams are large (50+ developers) and truly independent:

```text
Team A: Customer-facing features, deploys daily
Team B: Internal admin tools, deploys weekly
Teams never coordinate

Solution: Separate services for deployment independence
```

### Technology Constraints

If a component genuinely needs different technology:

```text
Main app: Ruby/Rails
ML inference: Python/TensorFlow

Solution: Separate Python service for ML
```

### Regulatory Requirements

If isolation is legally required:

```text
Main app: General features
Payment processing: PCI DSS compliance requires isolation

Solution: Isolated payment service
```

### Third-Party Wrapping

If a component primarily wraps external services:

```text
Main app: Core features
Search: Elasticsearch with complex query building

Solution: Search service wrapping Elasticsearch
```

Notice the pattern: real, specific, unavoidable reasons. Not "we might need to scale someday" or "microservices feel cleaner."

## The Integration Decision Framework

Before distributing, ask:

1. **Is there a specific problem we're solving?** Not theoretical—actual pain.
2. **Have we tried organizing within the monolith?** Namespaces, engines, concerns?
3. **Do we have the operational maturity?** Distributed systems require sophisticated monitoring, tracing, and deployment.
4. **Is the team ready?** Distributed systems need different skills and processes.
5. **Are we willing to pay the ongoing tax?** Complexity doesn't go away—it compounds.

If any answer is "no," stay integrated.

## Conclusion

Integrated systems are Rails' default for good reason:

- **Simpler**: One codebase, one database, one deployment
- **Faster**: Direct method calls, shared memory, no serialization
- **Safer**: Transactions that work, debugging that's tractable
- **Cheaper**: Less infrastructure, smaller teams, lower operational burden

The integrated system isn't a compromise—it's often the optimal architecture. Rails provides powerful tools for organizing large applications without fragmenting them.

Start integrated. Stay integrated until you can't. Extract services only for specific, unavoidable reasons.

That's the Rails way.
