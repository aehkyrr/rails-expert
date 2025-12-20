# The Majestic Monolith: Rails' Architectural Philosophy

## Introduction

DHH coined the term "Majestic Monolith" to describe the architectural approach Rails champions: a well-structured, integrated application that resists the siren call of microservices until they're genuinely needed.

The industry's rush to microservices left casualties: teams struggling with distributed system complexity, debugging nightmares across service boundaries, and deployment headaches—all for applications that didn't need that scale.

Rails takes a stand: **start with a monolith, and only extract services when you have specific, unavoidable reasons.**

## What is a Majestic Monolith?

A majestic monolith is:
- **Single codebase**: One Rails application, one repository
- **Shared database**: All code accesses the same database
- **In-process calls**: Components call each other directly, not via HTTP
- **Unified deployment**: Deploy everything together
- **Well-structured**: Organized with clear boundaries and responsibilities

What it's NOT:
- A "big ball of mud" with no structure
- Spaghetti code with tangled dependencies
- Impossible to understand or modify
- A stepping stone to "real" architecture

A monolith can be beautiful, maintainable, and scalable.

## Why Monoliths Win for Most Applications

### 1. Simplicity

**Monolith:**
```ruby
# In OrdersController
def create
  @order = Order.new(order_params)
  @order.user = current_user

  if @order.save
    OrderMailer.confirmation(@order).deliver_later
    InventoryService.reserve(@order.line_items)
    redirect_to @order
  else
    render :new
  end
end
```

**Microservices:**
```ruby
# In Orders Service
def create
  @order = Order.new(order_params)

  # Call Users Service
  user_response = HTTP.get("https://users-service/api/users/#{params[:user_id]}")
  raise unless user_response.success?
  @order.user_id = user_response.parsed_body['id']

  # Call Email Service
  email_response = HTTP.post("https://email-service/api/emails", json: {
    type: 'order_confirmation',
    order_id: @order.id
  })
  raise unless email_response.success?

  # Call Inventory Service
  inventory_response = HTTP.post("https://inventory-service/api/reservations", json: {
    items: @order.line_items.map(&:to_h)
  })
  raise unless inventory_response.success?

  # Coordinate transaction across services (good luck!)
end
```

Which would you rather debug at 3am?

### 2. Shared Database Benefits

**Transactions Work:**
```ruby
ActiveRecord::Base.transaction do
  order.save!
  order.line_items.each { |item| item.product.decrement!(:inventory) }
  Payment.create!(order: order, amount: order.total)
end
# All or nothing - simple
```

With microservices, distributed transactions are hard. Really hard. Two-phase commit, eventual consistency, compensating transactions—all complex solutions to a problem you created.

**Queries Just Work:**
```ruby
# Get all orders with products and users in one query
Order.includes(:user, line_items: :product)
     .where('orders.created_at > ?', 1.week.ago)
     .order(created_at: :desc)
```

Across microservices? You're writing custom aggregation code, caching strategies, and accepting denormalized data.

**Data Consistency is Automatic:**

In a monolith, foreign key constraints enforce referential integrity:

```ruby
class Order < ApplicationRecord
  belongs_to :user  # Database ensures user exists
end
```

In microservices, you're implementing eventual consistency, sagas, or accepting that data might be wrong.

### 3. Easier Debugging

**Monolith:**
```ruby
# Stack trace shows complete flow
OrdersController#create
  Order#save
    OrderMailer#confirmation
    InventoryService#reserve
      Product#decrement_inventory
```

You can step through with a debugger. Logs show the complete request. Errors have full context.

**Microservices:**

Debugging spans services, network calls fail mysteriously, distributed tracing adds complexity, correlation IDs must be threaded through, timeout errors mask root causes.

### 4. Faster Development

**New Feature in Monolith:**
1. Write migration
2. Add model logic
3. Update controller
4. Create view
5. Deploy

**New Feature in Microservices:**
1. Decide which services need changes
2. Update each service's schema (coordinate migrations!)
3. Update service APIs (version them!)
4. Update consuming services
5. Deploy services in correct order
6. Monitor for distributed failures

One takes hours. The other takes days or weeks.

### 5. Simpler Deployment

**Monolith:**
```bash
kamal deploy
```

One command. One container. One database. Done.

**Microservices:**

Deploy orchestration (Kubernetes), service mesh (Istio), service discovery, load balancing, inter-service authentication, distributed configuration, secrets management, health checks across services, canary deploys coordinated across services.

### 6. Lower Costs

**Monolith:**
- One server (scale vertically first)
- One database
- No inter-service networking
- Simpler monitoring
- Smaller team can manage

**Microservices:**
- Multiple services (minimum 3-5, often dozens)
- Multiple databases (or complex sharding)
- Service mesh infrastructure
- Distributed monitoring and tracing
- Larger team needed

Most applications don't have Google/Netflix scale. Don't adopt their architecture.

## When Microservices Actually Make Sense

Rails doesn't hate microservices. It hates **premature microservices**.

Extract services when you have **specific, unavoidable needs**:

### 1. Genuine Scale Requirements

If one component has radically different scaling needs:

```
Scenario: Video transcoding service
- Main app: 100 req/sec
- Video processing: Spiky, CPU-intensive, needs separate scaling

Solution: Extract video processing to separate service
```

### 2. Team Independence

If you have large, independent teams (>50 developers):

```
Scenario: Large enterprise with separate teams
- Team A: Customer-facing features
- Team B: Internal admin tools
- Teams never coordinate

Solution: Separate services can deploy independently
```

### 3. Technology Constraints

If one component genuinely needs different technology:

```
Scenario: Machine learning model
- Main app: Ruby/Rails
- ML inference: Python/TensorFlow

Solution: Separate Python service for ML
```

### 4. Security Boundaries

If regulatory or security requirements demand isolation:

```
Scenario: PCI compliance for payment processing
- Main app: General application
- Payment processing: Must be isolated for PCI DSS

Solution: Separate payment service
```

### 5. Third-Party Integration

If a component is essentially wrapping a third-party service:

```
Scenario: Search functionality
- Main app: Rails
- Search: Elasticsearch

Solution: Wrap Elasticsearch in a service layer
```

**Notice the pattern?** Real reasons, not "it feels cleaner" or "we might need to scale later."

## Building a Well-Structured Monolith

A majestic monolith has structure and boundaries:

### Use Namespaces

```ruby
# app/models/checkout/cart.rb
module Checkout
  class Cart < ApplicationRecord
  end
end

# app/models/inventory/product.rb
module Inventory
  class Product < ApplicationRecord
  end
end
```

Clear domain boundaries without separate services.

### Use Service Objects

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

    def create_order
      # ...
    end

    def reserve_inventory
      # ...
    end

    def charge_payment
      # ...
    end

    def send_confirmation
      # ...
    end
  end
end
```

Organized without network boundaries.

### Use Engines for Major Domains

Rails Engines provide isolation within a monolith:

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
- Routes
- Migrations
- Tests

But share:
- Database
- Process space
- Deployment

### Use Concerns for Cross-Cutting Features

```ruby
# app/models/concerns/archivable.rb
module Archivable
  extend ActiveSupport::Concern

  included do
    scope :archived, -> { where.not(archived_at: nil) }
    scope :active, -> { where(archived_at: nil) }
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end
end
```

Shared behavior without duplication.

## The Rails Way: Monolith First

Rails defaults to monolith architecture:

1. **Single Rails app** created with `rails new`
2. **Single database** configured in `database.yml`
3. **All components in one codebase** (models, controllers, views)
4. **Shared code** via inheritance, modules, concerns
5. **Single deployment** with one Dockerfile

This isn't limiting—it's liberating. You're free to solve actual problems instead of fighting distributed systems.

## Scaling the Monolith

Before extracting services, scale the monolith:

### 1. Vertical Scaling

Modern servers are powerful. One server can handle millions of requests:
- 64+ CPU cores
- 256+ GB RAM
- Fast NVMe storage

GitHub runs on monolithic Rails. Shopify serves billions with Rails. Basecamp handles millions of users with Rails.

### 2. Read Replicas

Split reads from writes:

```ruby
# config/database.yml
production:
  primary:
    adapter: postgresql
    host: primary.db
  replica:
    adapter: postgresql
    host: replica.db
    replica: true

# In models
class Product < ApplicationRecord
  connects_to database: { writing: :primary, reading: :replica }
end
```

### 3. Caching

Rails 8 includes Solid Cache for fragment and query caching:

```ruby
# Cache expensive queries
@products = Rails.cache.fetch("products/all", expires_in: 1.hour) do
  Product.includes(:category).order(:name)
end

# Cache rendered views
<% cache @product do %>
  <%= render @product %>
<% end %>
```

### 4. Background Jobs

Move slow work to background jobs with Solid Queue:

```ruby
class ExportJob < ApplicationJob
  queue_as :low_priority

  def perform(user)
    # Long-running export
  end
end

# In controller
ExportJob.perform_later(current_user)
```

### 5. Database Optimization

Optimize queries before blaming architecture:

```ruby
# Add indexes
add_index :orders, :user_id
add_index :orders, [:status, :created_at]

# Avoid N+1 queries
Order.includes(:user, :line_items).where(status: 'pending')

# Use select to reduce data transfer
Product.select(:id, :name, :price).where(category: 'electronics')
```

## Real-World Majestic Monoliths

### GitHub

- Millions of users
- Billions of requests
- Thousands of developers
- Still largely monolithic Rails

### Shopify

- Millions of merchants
- Billions in GMV
- Rails monolith with selective service extraction
- Chose modularity within monolith (components) over microservices

### Basecamp (by DHH himself)

- Millions of users
- Runs on a handful of servers
- Monolithic Rails application
- Proof of concept for Rails philosophy

## Common Objections Answered

**"But microservices let teams work independently!"**

Namespaces, engines, and good code organization provide independence without network calls.

**"But we need to scale different components differently!"**

Most applications don't. And when you do, extract that one component—not everything.

**"But microservices are more resilient!"**

Distributed systems have more failure modes. Partial failures are harder to reason about than total failures.

**"But everyone else is doing microservices!"**

Everyone else also rewrites their JavaScript framework every 18 months. Make your own decisions.

**"But we might need to scale later!"**

YAGNI (You Ain't Gonna Need It). Build for today's problems. Refactor when you have tomorrow's problems.

## Conclusion

The majestic monolith is Rails' answer to architecture:

- Start simple
- Stay simple until you can't
- Extract services for specific, real needs
- Never extract "just in case"

Microservices are a solution to specific problems. Most applications don't have those problems.

Build a majestic monolith. Let others deal with distributed transactions.
