# Rails Caching Strategies: Complete Guide

## Why Cache?

Caching stores the result of expensive operations so they don't need to be recalculated. A well-cached Rails app on modest hardware can serve thousands of concurrent users.

## Cache Stores

### Solid Cache (Rails 8 Default)

Database-backed caching:

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

No Redis needed. Uses your existing database.

### Memory Store

```ruby
config.cache_store = :memory_store, { size: 64.megabytes }
```

Fast but limited to single process. Good for development.

### Redis

```ruby
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
```

Use when you need sub-millisecond latency or already run Redis.

## Fragment Caching

Cache rendered view fragments.

### Basic Usage

```erb
<% cache @product do %>
  <%= render @product %>
<% end %>
```

Cache key: `views/products/1-20240115120000/abc123def`
- Model name and ID
- `updated_at` timestamp
- Template digest (view content hash)

Cache expires when:
- Product `updated_at` changes
- View template changes

### Custom Cache Keys

```erb
<% cache ['products', @product, I18n.locale] do %>
  <%= render @product %>
<% end %>
```

Cache separately per locale.

### Conditional Caching

```erb
<% cache_if @product.published?, @product do %>
  <%= render @product %>
<% end %>

<% cache_unless admin?, @product do %>
  <%= render @product %>
<% end %>
```

### Expiration

```erb
<% cache @product, expires_in: 1.hour do %>
  <%= render @product %>
<% end %>
```

## Russian Doll Caching

Nested caches that invalidate hierarchically.

### Setup

```ruby
class Product < ApplicationRecord
  belongs_to :category, touch: true
end
```

`touch: true` updates category's `updated_at` when product changes.

### View

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

**When product updates:**
- Product cache expires
- Category cache expires (was touched)
- Other product caches stay valid

**When adding product:**
- Touch category manually: `product.category.touch`
- Category cache expires
- All product caches stay valid

## Collection Caching

Cache multiple items efficiently:

```erb
<%= render partial: 'products/product', collection: @products, cached: true %>
```

Rails reads all cache entries in one multi-get instead of N individual reads.

### Custom Collection Keys

```erb
<%= render partial: 'products/product',
           collection: @products,
           cached: ->(product) { [I18n.locale, product, current_user.admin?] } %>
```

## Low-Level Caching

Cache any Ruby object:

### Basic Usage

```ruby
# Fetch from cache or execute block
result = Rails.cache.fetch("expensive_operation", expires_in: 12.hours) do
  perform_expensive_operation
end

# Write explicitly
Rails.cache.write("key", value, expires_in: 1.hour)

# Read explicitly
Rails.cache.read("key")

# Delete
Rails.cache.delete("key")

# Check existence
Rails.cache.exist?("key")
```

### Fetch Multi

Batch read multiple keys:

```ruby
product_ids = [1, 2, 3, 4, 5]

stats = Rails.cache.fetch_multi(*product_ids, namespace: "product_stats", expires_in: 1.hour) do |id|
  Product.find(id).calculate_stats
end
```

Only uncached items execute the block.

### Using cache_key_with_version

For model-based cache keys that auto-invalidate on updates:

```ruby
class Product < ApplicationRecord
  def competing_price
    Rails.cache.fetch("#{cache_key_with_version}/competing_price", expires_in: 12.hours) do
      Competitor::API.find_price(id)
    end
  end
end
```

`cache_key_with_version` generates keys like `products/233-20140225082222765838000/competing_price`:

- Model class name (`products`)
- Record ID (`233`)
- `updated_at` timestamp
- Your suffix (`competing_price`)

Cache automatically expires when the record is updated.

### Avoid Caching Active Record Objects

**Anti-pattern** - don't cache AR instances:

```ruby
# BAD: Caching AR objects directly
Rails.cache.fetch("super_admin_users", expires_in: 12.hours) do
  User.super_admins.to_a
end
```

**Why it's problematic:**

- Cached instances may have stale attributes
- Records could be deleted but still in cache
- Development mode cache behaves unreliably with code reloading

**Correct approach** - cache IDs or primitives:

```ruby
# GOOD: Cache IDs, load fresh records
ids = Rails.cache.fetch("super_admin_user_ids", expires_in: 12.hours) do
  User.super_admins.pluck(:id)
end
User.where(id: ids).to_a
```

This pattern gives you cache benefits while ensuring data freshness.

### Conditional Caching

```ruby
def featured_products
  return Product.featured unless Rails.cache.configured?

  Rails.cache.fetch("products/featured", expires_in: 10.minutes) do
    Product.featured.to_a
  end
end
```

## SQL Query Result Caching

Rails automatically caches identical SQL queries within a request:

```ruby
# In one request:
Product.find(1)  # Executes SQL
Product.find(1)  # Returns cached result

# Next request: cache cleared, queries again
```

This is automatic and always enabled.

## HTTP Caching

### Conditional GET (ETag)

```ruby
class ProductsController < ApplicationController
  def show
    @product = Product.find(params[:id])

    fresh_when @product
    # Rails handles ETag and Last-Modified headers
    # Returns 304 Not Modified if unchanged
  end
end
```

### Stale Check

```ruby
def show
  @product = Product.find(params[:id])

  if stale?(@product)
    respond_to do |format|
      format.html
      format.json { render json: @product }
    end
  end
end
```

## Cache Expiration Strategies

### Time-Based

```ruby
Rails.cache.fetch("key", expires_in: 1.hour)
```

Good for data that changes predictably.

### Event-Based

```ruby
class Product < ApplicationRecord
  after_save :clear_cache

  private

  def clear_cache
    Rails.cache.delete("products/all")
  end
end
```

Expires cache immediately when data changes.

### Version-Based

```ruby
cache_version = Rails.cache.fetch("cache_version") { 1 }

Rails.cache.fetch(["products", cache_version]) do
  Product.all.to_a
end

# Invalidate all product caches:
Rails.cache.increment("cache_version")
```

## Performance Monitoring

### Cache Hit Rate

```ruby
# Track hits and misses
Rails.cache.fetch("key") do
  Rails.cache.increment("cache_misses")
  expensive_operation
end

# Calculate hit rate
hits = Rails.cache.read("cache_hits") || 0
misses = Rails.cache.read("cache_misses") || 0
hit_rate = (hits.to_f / (hits + misses) * 100).round(2)
```

### Cache Size

```ruby
# Solid Cache
SolidCache::Entry.count
SolidCache::Entry.sum("LENGTH(value)") / 1024.0 / 1024.0  # MB
```

## Best Practices

1. **Cache expensive operations** (complex queries, API calls, calculations)
2. **Don't cache everything** (adds complexity)
3. **Use fragment caching** for views
4. **Implement Russian doll** for nested content
5. **Set reasonable expiry** times
6. **Monitor hit rates** to measure effectiveness
7. **Test caching** (verify cache works and expires correctly)
8. **Use cache keys** that invalidate appropriately
9. **Warm caches** for critical data
10. **Document caching** strategy for each feature

Master caching and your Rails app will handle 10x the traffic on the same hardware.
