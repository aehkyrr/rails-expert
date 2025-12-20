# Query Optimization: Performance and N+1 Prevention

## The N+1 Query Problem

The N+1 problem is the most common performance issue in Rails applications.

### What is N+1?

```ruby
# BAD: N+1 queries
products = Product.limit(10)  # 1 query
products.each do |product|
  puts product.category.name   # N queries (one per product!)
end
# Total: 1 + 10 = 11 queries
```

For each product, Rails fires a separate query to fetch its category. With 1000 products, that's 1001 queries!

### Detecting N+1

**In logs:**

```
Product Load (0.5ms)  SELECT * FROM products LIMIT 10
Category Load (0.2ms)  SELECT * FROM categories WHERE id = 1
Category Load (0.2ms)  SELECT * FROM categories WHERE id = 2
Category Load (0.2ms)  SELECT * FROM categories WHERE id = 3
... (repeats for each product)
```

**Using Bullet gem:**

```ruby
# Gemfile
gem 'bullet', group: :development

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.console = true
  Bullet.rails_logger = true
end
```

Bullet warns when N+1 detected and suggests eager loading.

## Eager Loading Solutions

### includes

Automatically chooses preload or eager_load:

```ruby
# GOOD: 2 queries total
products = Product.includes(:category).limit(10)
products.each do |product|
  puts product.category.name  # No additional queries!
end

# Queries:
# SELECT * FROM products LIMIT 10
# SELECT * FROM categories WHERE id IN (1,2,3,4,5,6,7,8,9,10)
```

### preload

Forces separate queries:

```ruby
products = Product.preload(:category, :tags)

# Queries:
# SELECT * FROM products
# SELECT * FROM categories WHERE id IN (...)
# SELECT * FROM tags INNER JOIN products_tags ON ...
```

Use when:
- You want predictable query behavior
- The association is large (separate queries more efficient)

### eager_load

Forces LEFT OUTER JOIN:

```ruby
products = Product.eager_load(:category)

# Query:
# SELECT products.*, categories.* FROM products
# LEFT OUTER JOIN categories ON categories.id = products.category_id
```

Use when:
- You need to query on associated table
- You want a single query

### Nested Eager Loading

```ruby
# Multiple levels deep
orders = Order.includes(line_items: { product: [:category, :tags] })

orders.each do |order|
  order.line_items.each do |item|
    puts item.product.name
    puts item.product.category.name
    puts item.product.tags.map(&:name).join(", ")
  end
end
# All data loaded with minimal queries!
```

### Conditional Eager Loading

```ruby
def index
  @products = Product.all

  # Only eager load if accessing categories
  @products = @products.includes(:category) if params[:show_categories]

  # Chain multiple includes
  @products = @products.includes(:tags) if params[:show_tags]
  @products = @products.includes(:reviews) if params[:show_reviews]
end
```

## Select Specific Columns

Reduce data transfer by selecting only needed columns:

```ruby
# BAD: Loads all columns
Product.all

# GOOD: Loads only needed columns
Product.select(:id, :name, :price)

# With calculations
Product.select('id, name, price, price * 0.9 AS discounted_price')

# CAUTION: Accessing non-selected columns returns nil
products = Product.select(:id, :name)
products.first.price  # => nil (not loaded!)
```

## Pluck and IDs

For extracting single values efficiently:

### pluck

```ruby
# BAD: Loads full objects
Product.all.map(&:name)  # Loads all columns, creates objects

# GOOD: Directly extracts column
Product.pluck(:name)  # Single query, returns array of strings

# Multiple columns
Product.pluck(:id, :name, :price)
# => [[1, "Widget", 9.99], [2, "Gadget", 14.99]]

# With conditions
Product.where(available: true).pluck(:name)
```

### ids

Shortcut for plucking IDs:

```ruby
# BAD
Product.all.map(&:id)

# GOOD
Product.ids  # Equivalent to Product.pluck(:id)
```

### pick

Get single value from first record:

```ruby
Product.pick(:name)  # Faster than Product.first.name
Product.where(sku: "ABC123").pick(:price)
```

## Batch Processing

For processing large datasets without loading everything into memory.

### find_each

```ruby
# BAD: Loads all 1,000,000 products into memory
Product.all.each do |product|
  product.update(processed: true)
end

# GOOD: Processes in batches of 1000 (default)
Product.find_each do |product|
  product.update(processed: true)
end

# Custom batch size
Product.find_each(batch_size: 500) do |product|
  product.update(processed: true)
end

# Start from specific ID
Product.find_each(start: 10000) do |product|
  # Process products with id >= 10000
end
```

### find_in_batches

Process batches as arrays:

```ruby
Product.find_in_batches(batch_size: 1000) do |products|
  # products is an array of 1000 Product objects
  bulk_operation(products)
end
```

### in_batches

Update records in batches:

```ruby
Product.where(available: false).in_batches(of: 1000) do |batch|
  batch.update_all(archived: true)
  sleep(1)  # Rate limiting
end
```

## Counting Efficiently

### count vs size vs length

```ruby
products = Product.where(available: true)

# count: Always fires COUNT query
products.count  # SELECT COUNT(*) FROM products WHERE available = true

# size: Smart - uses loaded records or fires COUNT
products.size   # COUNT query if not loaded, array.size if loaded

# length: Always loads all records
products.length  # SELECT * FROM products WHERE available = true (then count in Ruby)
```

**Best practice:** Use `size` - it's smart about whether to query.

### exists?

Check for existence without loading records:

```ruby
# BAD
Product.where(sku: "ABC123").any?  # Loads records

# GOOD
Product.where(sku: "ABC123").exists?  # SELECT 1 FROM products WHERE sku = 'ABC123' LIMIT 1

# Check by ID
Product.exists?(1)

# With conditions
Product.exists?(name: "Widget", available: true)
```

## Avoiding Extra Queries

### Touching Associations

```ruby
# BAD: Fires query for each associated record
category.products.each(&:touch)

# GOOD: Single UPDATE query
category.products.touch_all
```

### Bulk Operations

```ruby
# BAD: N queries
products.each { |p| p.update(available: true) }

# GOOD: 1 query
Product.where(id: product_ids).update_all(available: true)

# GOOD: With calculations
Product.where(category_id: 5).update_all("price = price * 1.1")
```

### Delete vs Destroy

```ruby
# destroy: Loads records, runs callbacks, fires N queries
products.each(&:destroy)

# delete: Single DELETE query, no callbacks
Product.where(id: product_ids).delete_all

# destroy_all: Loads and destroys (runs callbacks)
Product.where(id: product_ids).destroy_all
```

## Index Optimization

### Adding Indexes

```ruby
# Migration
add_index :products, :sku
add_index :products, [:category_id, :available]
add_index :products, :name, unique: true
```

### When to Index

Index these columns:
- Foreign keys (category_id, user_id, etc.)
- Columns in WHERE clauses
- Columns in ORDER BY
- Columns in JOIN conditions
- Unique constraints (email, sku, etc.)

**Don't over-index:**
- Write operations become slower
- Indexes take disk space
- PostgreSQL recommends < 10 indexes per table

### Checking Index Usage

```ruby
# PostgreSQL
Product.connection.execute("EXPLAIN ANALYZE SELECT * FROM products WHERE sku = 'ABC123'")

# Look for:
# - "Seq Scan" (bad - full table scan)
# - "Index Scan" (good - using index)
```

## Query Analysis

### EXPLAIN

See query execution plan:

```ruby
products = Product.where(available: true).includes(:category)
puts products.explain

# Output shows:
# - Join strategy
# - Index usage
# - Estimated rows
# - Cost
```

### Logging

```ruby
# config/environments/development.rb
config.log_level = :debug

# Logs show:
# - SQL queries
# - Query duration
# - Number of rows returned
```

## Scopes for Performance

### Efficient Scopes

```ruby
class Product < ApplicationRecord
  # GOOD: Chainable, lazy-loaded
  scope :available, -> { where(available: true) }
  scope :cheap, -> { where("price < ?", 10) }
  scope :in_stock, -> { where("quantity > ?", 0) }

  # GOOD: With eager loading built-in
  scope :with_category, -> { includes(:category) }
  scope :with_tags, -> { includes(:tags) }
end

# Usage:
Product.available.cheap.with_category
```

### Avoiding Scope Pitfalls

```ruby
# BAD: Evaluated immediately
scope :created_today, where(created_at: Date.today)

# GOOD: Lambda evaluates when called
scope :created_today, -> { where(created_at: Date.today) }
```

## Caching Strategies

### Query Caching

Rails automatically caches identical queries within a request:

```ruby
# First query hits database
Product.find(1)

# Second query uses cache (within same request)
Product.find(1)

# Different request = new cache
```

### Fragment Caching

Cache rendered partials:

```erb
<% cache @product do %>
  <%= render @product %>
<% end %>
```

### Russian Doll Caching

Nested caches that invalidate properly:

```ruby
class Product < ApplicationRecord
  belongs_to :category, touch: true  # Update category when product changes
end
```

```erb
<% cache @category do %>
  <h2><%= @category.name %></h2>

  <% @category.products.each do |product| %>
    <% cache product do %>
      <%= render product %>
    <% end %>
  <% end %>
<% end %>
```

### Low-Level Caching

```ruby
def expensive_calculation
  Rails.cache.fetch("product_#{id}/stats", expires_in: 1.hour) do
    # Expensive operation
    calculate_statistics
  end
end
```

## Advanced Optimization Patterns

### Subqueries

```ruby
# Find products in top categories
expensive_categories = Category.where("average_price > ?", 100)

Product.where(category: expensive_categories)
# SELECT * FROM products WHERE category_id IN (
#   SELECT id FROM categories WHERE average_price > 100
# )
```

### Raw SQL When Needed

```ruby
# Complex query that's hard in ActiveRecord
Product.find_by_sql("
  SELECT p.*, COUNT(r.id) AS review_count
  FROM products p
  LEFT JOIN reviews r ON r.product_id = p.id
  GROUP BY p.id
  HAVING COUNT(r.id) > 10
  ORDER BY review_count DESC
")
```

### Database Views

```ruby
# Migration
def up
  execute <<-SQL
    CREATE VIEW popular_products AS
    SELECT p.*, COUNT(o.id) AS order_count
    FROM products p
    LEFT JOIN orders o ON o.product_id = p.id
    GROUP BY p.id
    HAVING COUNT(o.id) > 100
  SQL
end

# Model
class PopularProduct < ApplicationRecord
  self.table_name = "popular_products"
  self.primary_key = "id"

  def readonly?
    true
  end
end
```

## Profiling Tools

### rack-mini-profiler

```ruby
# Gemfile
gem 'rack-mini-profiler'

# Shows in-page:
# - SQL queries
# - Duration
# - N+1 warnings
# - Memory usage
```

### scout_apm / skylight

Production performance monitoring:
- Track slow queries
- Identify N+1 problems
- Monitor endpoints
- Analyze trends

## Performance Checklist

**Always:**
- [ ] Eager load associations (`includes`)
- [ ] Add indexes on foreign keys
- [ ] Use `find_each` for large datasets
- [ ] Use `pluck` for simple extractions
- [ ] Use `exists?` not `any?` for existence checks
- [ ] Use `select` to limit loaded columns

**Avoid:**
- [ ] N+1 queries (use Bullet gem)
- [ ] Loading unnecessary data
- [ ] Performing calculations in Ruby (use SQL)
- [ ] Missing indexes on frequently queried columns
- [ ] Running updates/deletes in loops

**Monitor:**
- [ ] Slow query logs
- [ ] N+1 query warnings
- [ ] Database connection pool
- [ ] Query execution plans (EXPLAIN)

## Conclusion

Query optimization in Rails is about:
1. **Preventing N+1** with eager loading
2. **Limiting data** with select and pluck
3. **Batching** large operations
4. **Indexing** frequently queried columns
5. **Profiling** to find bottlenecks
6. **Caching** expensive operations

Master these techniques and your Rails app will stay fast as it scales.
