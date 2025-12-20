# Solid Suite: Database-Backed Infrastructure

## The Philosophy

Rails 8 introduced the "Solid" gems: Solid Cache, Solid Queue, and Solid Cable. These replace external dependencies (Redis, Sidekiq, etc.) with database-backed implementations.

The philosophy: **Your database is already there. Use it.**

Benefits:
- Fewer moving parts
- Simpler deployment
- One backup strategy
- Familiar query tools
- Lower hosting costs
- Built on modern SQL

This is the "integrated systems" philosophy applied to infrastructure.

## Solid Cache

### The Problem with Traditional Caching

Traditionally, Rails applications used Redis or Memcached for caching:

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
```

This requires:
- Separate Redis server
- Redis monitoring
- Redis backups
- Redis memory management
- Additional infrastructure cost
- Network latency to Redis

### The Solid Cache Solution

**Solid Cache** stores cached data in your database:

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store
```

That's it. No external service needed.

### How It Works

Solid Cache creates a `solid_cache_entries` table:

```ruby
create_table :solid_cache_entries do |t|
  t.binary :key, null: false, limit: 1024
  t.binary :value, null: false, limit: 512.megabytes
  t.datetime :created_at, null: false

  t.index :key, unique: true
  t.index :created_at
end
```

When you cache:

```ruby
Rails.cache.fetch("products/all", expires_in: 1.hour) do
  Product.all.to_a
end
```

Solid Cache:
1. Hashes the key
2. Stores value in `solid_cache_entries` table
3. Sets `created_at` for expiry
4. Returns cached value on subsequent calls

### Performance Characteristics

**Reads:** Fast—simple indexed lookup
**Writes:** Fast—single INSERT with conflict resolution
**Expiry:** Automatic via background job (clears old entries)
**Memory:** Database handles caching itself

Modern databases (PostgreSQL, MySQL 8+) are fast. For most applications, Solid Cache performs comparably to Redis.

### Configuration

```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store,
  expires_in: 1.day,
  namespace: "myapp",
  error_handler: ->(method:, returning:, exception:) {
    Rails.logger.error("SolidCache error: #{exception}")
  }
```

### When to Use Redis Instead

Use Redis if:
- You need sub-millisecond latency
- You're caching terabytes of data
- You use Redis-specific features (pub/sub, geospatial)

For most apps? Solid Cache is simpler and sufficient.

## Solid Queue

### The Problem with Background Job Services

Traditionally, Rails apps used Redis-backed job processors:

```ruby
# Sidekiq
config.active_job.queue_adapter = :sidekiq
# Plus:
# - Redis server
# - Sidekiq process
# - Sidekiq web UI
# - Redis monitoring
```

### The Solid Queue Solution

**Solid Queue** stores jobs in your database:

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue
```

No external dependencies.

### How It Works

Solid Queue creates job tables:

```ruby
create_table :solid_queue_jobs do |t|
  t.string :queue_name, null: false
  t.string :class_name, null: false
  t.text :arguments
  t.integer :priority, default: 0
  t.string :active_job_id
  t.datetime :scheduled_at
  t.datetime :finished_at
  t.string :concurrency_key

  t.timestamps

  t.index [:queue_name, :finished_at]
  t.index [:scheduled_at, :finished_at]
  t.index :concurrency_key
end
```

When you enqueue a job:

```ruby
ExportJob.perform_later(user)
```

Solid Queue:
1. Serializes job to database
2. Worker polls for jobs using `FOR UPDATE SKIP LOCKED`
3. Executes job
4. Marks job as finished

### FOR UPDATE SKIP LOCKED

This is the secret sauce. Modern SQL (PostgreSQL 9.5+, MySQL 8.0+) supports:

```sql
SELECT * FROM solid_queue_jobs
WHERE queue_name = 'default'
  AND finished_at IS NULL
ORDER BY priority DESC, created_at ASC
LIMIT 1
FOR UPDATE SKIP LOCKED
```

This atomically:
- Finds next job
- Locks it
- Skips locked jobs (being processed by other workers)
- Returns immediately

No race conditions. No Redis needed.

### Configuration

```ruby
# config/solid_queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "*"
      threads: 5
      processes: 3
      polling_interval: 0.1
```

### Deployment

Solid Queue runs as part of your Rails app:

```bash
bundle exec rails solid_queue:start
```

Or use a Procfile:

```
web: bundle exec rails server
worker: bundle exec rails solid_queue:start
```

### Advanced Features

**Concurrency Control:**

```ruby
class ProcessReportJob < ApplicationJob
  queue_as :default
  concurrency limit: 1, key: ->(report) { "report:#{report.id}" }

  def perform(report)
    # Only one job per report at a time
  end
end
```

**Recurring Jobs:**

```ruby
# config/recurring.yml
schedule:
  cleanup:
    class: CleanupJob
    schedule: "0 3 * * *"  # Daily at 3am
  reminder:
    class: ReminderJob
    schedule: "*/15 * * * *"  # Every 15 minutes
```

### When to Use Sidekiq Instead

Use Sidekiq if:
- You need Redis for caching anyway
- You process millions of jobs/hour
- You use Sidekiq-specific gems

For most apps? Solid Queue is simpler and sufficient.

## Solid Cable

### The Problem with Action Cable + Redis

Action Cable traditionally used Redis for pub/sub:

```ruby
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
```

This requires:
- Redis server for pub/sub
- Redis HA for reliability
- Another service to monitor

### The Solid Cable Solution

**Solid Cable** uses your database for pub/sub:

```ruby
# config/cable.yml
production:
  adapter: solid_cable
```

No Redis needed.

### How It Works

Solid Cable creates a messages table:

```ruby
create_table :solid_cable_messages do |t|
  t.binary :channel, null: false, limit: 1024
  t.binary :payload, null: false, limit: 536870912
  t.datetime :created_at, null: false

  t.index :channel
  t.index :created_at
end
```

When broadcasting:

```ruby
ActionCable.server.broadcast("chat:#{room.id}", {
  message: "Hello!",
  user: current_user.name
})
```

Solid Cable:
1. Writes message to `solid_cable_messages`
2. Polling mechanism notifies subscribers
3. Message delivered to WebSocket connections

### Polling Strategy

Solid Cable polls the database for new messages:

```ruby
# config/cable.yml
production:
  adapter: solid_cable
  polling_interval: 0.1  # 100ms
  message_retention: 1.day
```

Every 100ms, workers check for new messages since last poll.

### Message Retention

Messages are retained for debugging:

```ruby
# Messages older than 1 day are auto-deleted
config.solid_cable.message_retention = 1.day
```

### Performance

Polling every 100ms means:
- Latency: ~50-150ms (average)
- Throughput: Thousands of messages/second
- Sufficient for most real-time features

If you need sub-100ms latency, use Redis. For chat, notifications, live updates? Solid Cable works great.

### When to Use Redis Instead

Use Redis if:
- You need sub-100ms latency
- You're broadcasting to millions of connections
- You already run Redis for other reasons

For most apps? Solid Cable is simpler and sufficient.

## Solid Stack Philosophy

### Fewer Services

**Traditional Stack:**
- Application server (Rails)
- Database (PostgreSQL)
- Cache (Redis)
- Job processor (Redis + Sidekiq)
- Pub/sub (Redis)

Result: 5 services to deploy, monitor, backup, scale

**Solid Stack:**
- Application server (Rails)
- Database (PostgreSQL)

Result: 2 services. Everything else uses the database.

### Single Database Backup

With Solid Stack, one database backup captures:
- Application data
- Cached data (Solid Cache)
- Pending jobs (Solid Queue)
- Recent messages (Solid Cable)

Restore from backup and everything works.

### Simplified Deployment

```yaml
# config/deploy.yml - Traditional
services:
  web:
    image: myapp
  worker:
    image: myapp
    command: sidekiq
  redis:
    image: redis:7
```

```yaml
# config/deploy.yml - Solid Stack
services:
  web:
    image: myapp
  worker:
    image: myapp
    command: solid_queue:start
# That's it. No redis.
```

### Lower Costs

**Traditional Stack Hosting:**
- App server: $50/month
- Database: $50/month
- Redis: $30/month
- **Total: $130/month**

**Solid Stack Hosting:**
- App server: $50/month
- Database: $60/month (slightly larger)
- **Total: $110/month**

Plus: Less complexity, fewer bills, simpler monitoring.

### Modern SQL Features

Solid Stack leverages modern SQL:

**FOR UPDATE SKIP LOCKED** (job processing):
- PostgreSQL 9.5+ (2016)
- MySQL 8.0+ (2018)
- SQLite (not supported, use PostgreSQL/MySQL in production)

These features make database-backed queues performant.

## When to Use Solid Stack

### Perfect For

- New Rails 8 applications
- Applications with <1M users
- Teams wanting simplicity
- Cost-conscious deployments
- Developer-friendly stack

### Consider Alternatives If

- Sub-millisecond latency required
- Millions of jobs per hour
- Already heavily invested in Redis
- Extreme scale requirements

## Migrating to Solid Stack

### From Redis to Solid Cache

```ruby
# Before
config.cache_store = :redis_cache_store

# After
config.cache_store = :solid_cache_store
```

Run migrations:
```bash
bin/rails solid_cache:install:migrations
bin/rails db:migrate
```

Cache automatically uses database.

### From Sidekiq to Solid Queue

```ruby
# Before
config.active_job.queue_adapter = :sidekiq

# After
config.active_job.queue_adapter = :solid_queue
```

Run migrations:
```bash
bin/rails solid_queue:install
bin/rails db:migrate
```

Jobs automatically use database.

### From Redis Cable to Solid Cable

```yaml
# config/cable.yml - Before
production:
  adapter: redis
  url: <%= ENV['REDIS_URL'] %>

# config/cable.yml - After
production:
  adapter: solid_cable
```

Run migrations:
```bash
bin/rails solid_cable:install
bin/rails db:migrate
```

WebSockets automatically use database.

## Monitoring Solid Stack

### Solid Cache Monitoring

```ruby
# Check cache size
cache_size = SolidCache::Entry.count
cache_mb = SolidCache::Entry.sum("LENGTH(value)") / 1024.0 / 1024.0

# Check hit rate (app-level tracking)
Rails.cache.stats
```

### Solid Queue Monitoring

```ruby
# Check queue depths
Solid Queue::Job.where(finished_at: nil).group(:queue_name).count

# Check failed jobs
SolidQueue::Job.where.not(error: nil)

# Job latency
SolidQueue::Job.where(finished_at: nil)
  .average("EXTRACT(EPOCH FROM (NOW() - created_at))")
```

### Solid Cable Monitoring

```ruby
# Check message retention
SolidCable::Message.where("created_at > ?", 1.hour.ago).count

# Check message age
SolidCable::Message.maximum(:created_at)
```

## Performance Tuning

### Database Connections

Solid Stack needs adequate database connections:

```ruby
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } + 10 %>
  # +10 for Solid Queue workers
```

### Indexes

Ensure proper indexes exist:

```ruby
# Solid Queue indexes
add_index :solid_queue_jobs, [:queue_name, :finished_at]
add_index :solid_queue_jobs, [:scheduled_at, :finished_at]

# Solid Cache indexes
add_index :solid_cache_entries, :key, unique: true
add_index :solid_cache_entries, :created_at

# Solid Cable indexes
add_index :solid_cable_messages, :channel
add_index :solid_cable_messages, :created_at
```

### Database Vacuum (PostgreSQL)

Enable auto-vacuum for high-turnover tables:

```sql
ALTER TABLE solid_queue_jobs SET (autovacuum_vacuum_scale_factor = 0.01);
ALTER TABLE solid_cache_entries SET (autovacuum_vacuum_scale_factor = 0.01);
ALTER TABLE solid_cable_messages SET (autovacuum_vacuum_scale_factor = 0.01);
```

## Conclusion

Solid Stack represents Rails philosophy:

- **Integrated over distributed**
- **Simple over complex**
- **One database over many services**
- **Modern SQL over external dependencies**

It's not about performance—modern databases are fast. It's about simplicity, reliability, and maintainability.

Solid Cache, Solid Queue, and Solid Cable let you build and deploy Rails applications with minimal infrastructure.

That's the Rails way: beautiful simplicity at every layer.
