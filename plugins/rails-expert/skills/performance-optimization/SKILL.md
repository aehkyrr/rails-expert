---
name: performance-optimization
description: This skill should be used when the user asks about Rails performance optimization, slow queries, caching strategies, database indexing, N+1 query prevention, memory optimization, asset optimization, profiling, benchmarking, Rack Mini Profiler, Bullet gem, query analysis, Russian doll caching, fragment caching, page speed, or production performance tuning. Also use when discussing YJIT, Puma configuration, or scalability. Examples:

<example>
Context: User's app is slow
user: "My product listing page takes 5 seconds to load"
assistant: "Let me help you profile and optimize this. We'll check for N+1 queries and caching opportunities."
<commentary>
This relates to performance profiling and query optimization.
</commentary>
</example>

<example>
Context: User wants to improve caching
user: "What's the best caching strategy for my product catalog?"
assistant: "I'll explain fragment caching, Russian doll caching, and Solid Cache in Rails 8."
<commentary>
This involves caching strategies and Rails 8's Solid Cache.
</commentary>
</example>

<example>
Context: User asks about production optimization
user: "How should I configure Puma for production?"
assistant: "Let me explain thread/worker configuration and YJIT for optimal performance."
<commentary>
This relates to production server configuration and performance tuning.
</commentary>
</example>
---

# Performance & Optimization: Rails at Scale

## Overview

Rails applications can handle massive scale with proper optimization. Performance tuning involves multiple layers:

- **Database optimization**: Queries, indexes, eager loading
- **Caching**: Fragment, query, and low-level caching
- **Asset optimization**: Compression, CDN, HTTP/2
- **Application server**: Puma threads and workers
- **Ruby optimization**: YJIT, memory allocators
- **Profiling**: Identifying bottlenecks

Rails 8 provides excellent performance out of the box with Solid Cache, Thruster, and modern defaults.

## Database Performance

### N+1 Query Prevention

The #1 performance problem in Rails apps:

**Problem:**
```ruby
# 1 query for products + N queries for categories
products = Product.limit(10)
products.each { |p| puts p.category.name }  # N additional queries!
```

**Solution:**
```ruby
# 2 queries total
products = Product.includes(:category).limit(10)
products.each { |p| puts p.category.name }  # No additional queries
```

Use the **Bullet** gem in development to detect N+1:

```ruby
# Gemfile
gem 'bullet', group: :development

# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.console = true
end
```

### Strict Loading

Enforce eager loading by raising errors when associations are lazily loaded:

```ruby
# On a relation - raises ActiveRecord::StrictLoadingViolationError
user = User.strict_loading.first
user.address.city  # raises error - not eager loaded

# On a record
user = User.first
user.strict_loading!
user.comments.to_a  # raises error

# N+1 only mode - allows singular associations, catches collection lazy loads
user.strict_loading!(mode: :n_plus_one_only)
user.address.city  # allowed (singular)
user.comments.first.likes.to_a  # raises error (N+1 risk)

# On an association
class Author < ApplicationRecord
  has_many :books, strict_loading: true
end
```

**App-wide configuration:**

```ruby
# config/application.rb
config.active_record.strict_loading_by_default = true

# Log instead of raise
config.active_record.action_on_strict_loading_violation = :log
```

Use `strict_loading` in development/staging to catch N+1 queries before production.

### Database Indexes

Add indexes for frequently queried columns:

```ruby
# Migration
add_index :products, :sku
add_index :products, [:category_id, :available]
add_index :products, :name, unique: true
```

**When to index:**
- Foreign keys (category_id, user_id)
- WHERE clause columns
- ORDER BY columns
- JOIN conditions
- Unique constraints

**Check with EXPLAIN:**
```ruby
Product.where(category_id: 5).explain
# Look for "Index Scan" (good) vs "Seq Scan" (bad)
```

### Query Optimization

```ruby
# Select only needed columns
Product.select(:id, :name, :price)

# Use pluck for single values
Product.pluck(:name)  # Returns array of names

# Count efficiently
Product.count  # COUNT(*) query
Product.size   # Smart: uses count or length based on context

# Check existence
Product.exists?(name: "Widget")  # Fast

# Batch processing
Product.find_each { |p| process(p) }  # Loads in batches
```

## Caching Strategies

Rails 8 uses **Solid Cache** by default (database-backed).

### Fragment Caching

Cache rendered view fragments:

```erb
<% cache @product do %>
  <%= render @product %>
<% end %>
```

Cache key includes:
- Model name and ID
- `updated_at` timestamp
- Template digest (auto-expires when view changes)

### Collection Caching

Cache multiple items efficiently:

```erb
<%= render partial: 'products/product', collection: @products, cached: true %>
```

Reads all caches in one query, much faster than individual caching.

### Russian Doll Caching

Nest caches that invalidate properly:

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

When product updates:
- Product cache expires (updated_at changed)
- Category cache expires (touched via belongs_to)
- Other product caches reused

### Low-Level Caching

```ruby
# Cache expensive calculations
def complex_stats
  Rails.cache.fetch("product_#{id}/stats", expires_in: 1.hour) do
    calculate_expensive_statistics
  end
end

# Cache with dependencies
Rails.cache.fetch(["product", id, :reviews, last_review_at]) do
  reviews.includes(:user).order(created_at: :desc).limit(10)
end
```

### SQL Query Caching

Rails automatically caches identical queries within a request:

```ruby
Product.find(1)  # Fires query
Product.find(1)  # Uses cache (within same request)
```

## Asset Optimization

### Propshaft + Thruster

Rails 8's asset pipeline:

**Propshaft** handles:
- Digest fingerprinting (cache busting)
- Import map generation
- Asset precompilation

**Thruster** handles:
- Static file serving
- Gzip/Brotli compression
- Immutable caching headers
- X-Sendfile acceleration

### CDN Integration

```ruby
# config/environments/production.rb
config.asset_host = 'https://cdn.example.com'
```

Serves assets from CDN for faster global delivery.

### Image Optimization

```ruby
# Use Active Storage variants
<%= image_tag @product.image.variant(resize_to_limit: [800, 600]) %>

# Or ImageProcessing gem
<%= image_tag @product.image.variant(resize_and_pad: [800, 600, background: "white"]) %>
```

## Application Server Optimization

### Puma Configuration

```ruby
# config/puma.rb
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

workers ENV.fetch("WEB_CONCURRENCY") { 2 }

preload_app!
```

**Threads:** Handle concurrent requests (5 is good default)
**Workers:** Separate processes for parallelism (1 per CPU core)

**Rules of thumb:**
- More threads = better throughput, slightly higher latency
- More workers = true parallelism, more memory
- Start with: 2 workers, 5 threads per worker

### YJIT (Just-In-Time Compiler)

Rails 8 enables YJIT by default (Ruby 3.3+):

```ruby
# config/application.rb
config.yjit = true  # Enabled by default in Rails 8
```

YJIT benefits:
- 15-30% faster execution
- Slightly higher memory usage
- Worth it for almost all apps

### Memory Allocators

Use jemalloc for better memory management:

```dockerfile
# Dockerfile
RUN apt-get install -y libjemalloc2
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
```

Reduces memory fragmentation with threaded servers.

## Profiling Tools

### Rack Mini Profiler

```ruby
# Gemfile
gem 'rack-mini-profiler'
```

Shows in-page:
- SQL queries and duration
- View rendering time
- Partial rendering breakdown
- Memory usage
- N+1 warnings

Appears in top-left corner of every page in development.

### Bullet (N+1 Detection)

```ruby
# Gemfile
gem 'bullet', group: :development

# Detects:
# - N+1 queries (missing includes)
# - Unused eager loading
# - Unnecessary counter cache
```

### Scout APM / Skylight

Production performance monitoring:
- Endpoint response times
- Slow query tracking
- N+1 detection in production
- Memory usage trends
- Error tracking

## Performance Best Practices

### Database

1. **Eager load** associations with `includes`
2. **Add indexes** on foreign keys and WHERE columns
3. **Use select** to limit loaded columns
4. **Use pluck** for extracting values
5. **Batch process** with `find_each`
6. **Avoid COUNT queries** when possible
7. **Use EXISTS** for existence checks
8. **Profile queries** with EXPLAIN

### Caching

1. **Cache expensive operations** with `Rails.cache.fetch`
2. **Use fragment caching** for views
3. **Implement Russian doll caching** for nested content
4. **Use Solid Cache** (Rails 8 default)
5. **Cache API responses** from external services
6. **Set appropriate expiry** times
7. **Use cache sweepers** sparingly
8. **Monitor cache hit rates**

### Code

1. **Avoid N+1 queries** (use Bullet)
2. **Keep actions thin** (fat models, skinny controllers)
3. **Use background jobs** for slow operations
4. **Optimize Ruby code** (avoid unnecessary allocations)
5. **Use YJIT** (enabled by default Rails 8)
6. **Profile regularly** (Rack Mini Profiler)
7. **Monitor production** (APM tools)
8. **Load test** before major releases

### Assets

1. **Use CDN** for static assets
2. **Enable compression** (Thruster handles this)
3. **Optimize images** (Active Storage variants)
4. **Use modern formats** (WebP for images)
5. **Lazy load** below-the-fold content
6. **Minimize JavaScript** (Hotwire over heavy frameworks)
7. **Use HTTP/2** (Thruster supports this)
8. **Cache immutable** assets forever

## Measuring Performance

### Benchmarking

```ruby
require 'benchmark'

# Compare implementations
Benchmark.bm do |x|
  x.report("approach 1:") { 1000.times { slow_method } }
  x.report("approach 2:") { 1000.times { fast_method } }
end
```

### Load Testing

```bash
# Apache Bench
ab -n 1000 -c 10 https://myapp.com/products

# wrk
wrk -t12 -c400 -d30s https://myapp.com/products
```

### New Relic / Scout / Skylight

Production APM provides:
- Response time distributions
- Slow endpoint identification
- Database query analysis
- External API latency
- Error rates and patterns

## Common Performance Issues

### Symptom: Slow Page Load

**Causes:**
- N+1 queries
- Missing indexes
- Large result sets
- Expensive view rendering
- Missing fragment caching

**Solutions:**
1. Profile with Rack Mini Profiler
2. Check for N+1 with Bullet
3. Add eager loading (`includes`)
4. Add indexes
5. Implement caching

### Symptom: High Memory Usage

**Causes:**
- Memory leaks
- Large object allocations
- Inefficient garbage collection
- Too many Puma workers

**Solutions:**
1. Use jemalloc allocator
2. Reduce Puma workers
3. Profile with `memory_profiler` gem
4. Find memory leaks with `derailed_benchmarks`

### Symptom: High Database Load

**Causes:**
- Missing indexes
- Inefficient queries
- N+1 problems
- Missing caching

**Solutions:**
1. Add indexes on foreign keys
2. Use `includes` for associations
3. Implement query caching
4. Use database connection pooling
5. Consider read replicas

## Further Reading

For deeper exploration:

- **`references/caching-guide.md`**: Complete caching strategies guide
- **`references/profiling-tools.md`**: How to profile and debug performance

For code examples:

- **`examples/optimization-patterns.rb`**: Common optimization patterns

## Summary

Rails performance involves:
- **Database optimization**: Indexes, eager loading, query efficiency
- **Caching**: Fragment, low-level, query caching (Solid Cache)
- **Asset optimization**: Propshaft, Thruster, CDN
- **Server tuning**: Puma configuration, YJIT
- **Profiling**: Finding bottlenecks before guessing
- **Monitoring**: Production performance tracking

Master these techniques and your Rails app will scale to millions of users.
