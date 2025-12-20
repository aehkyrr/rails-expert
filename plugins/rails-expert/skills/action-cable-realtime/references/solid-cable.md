# Solid Cable: Database-Backed WebSockets

## Overview

Solid Cable is Rails 8's database-backed adapter for Action Cable, replacing Redis for pub/sub messaging. It's part of the "Solid" suite (alongside Solid Cache and Solid Queue) that eliminates external dependencies.

**Philosophy:**
- Your database is already there—use it
- Simpler deployment (no Redis cluster)
- One backup strategy
- Lower infrastructure costs
- Built on modern SQL polling

## How It Works

### Architecture

```
Browser → WebSocket → Rails → Solid Cable → Database → All Connected Clients
```

Solid Cable:
1. Stores messages in `solid_cable_messages` table
2. Polls database for new messages (~100ms interval)
3. Delivers messages to subscribed WebSocket connections
4. Automatically cleans up old messages

### Configuration

```yaml
# config/cable.yml
development:
  adapter: async  # In-memory, development only

test:
  adapter: test  # No actual connections

production:
  adapter: solid_cable
  polling_interval: 0.1  # Check every 100ms
  message_retention: 1.day  # Keep messages for debugging
```

### Installation

```bash
# Install Solid Cable
bin/rails solid_cable:install

# Run migrations
bin/rails db:migrate
```

Creates:

```ruby
# db/migrate/xxx_create_solid_cable_tables.rb
create_table :solid_cable_messages do |t|
  t.binary :channel, null: false, limit: 1024
  t.binary :payload, null: false, limit: 536_870_912  # 512 MB
  t.datetime :created_at, null: false, precision: 6

  t.index :channel
  t.index :created_at
end
```

## Usage

No code changes needed! Solid Cable is a drop-in replacement for Redis:

```ruby
# Broadcasting works the same
ActionCable.server.broadcast("chat_room_1", { message: "Hello!" })

# Channels work the same
class ChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "chat_room_#{params[:room_id]}"
  end
end
```

Everything else stays identical.

## Performance Characteristics

### Latency

- **Polling interval**: 100ms (default, configurable)
- **Average latency**: 50-150ms
- **Redis latency**: <50ms

**Verdict:** Solid Cable is ~2-3x slower than Redis, but still fast enough for most real-time features.

### Throughput

- **Messages/second**: Thousands (depends on database)
- **Concurrent connections**: Thousands (database connection limit)
- **Redis throughput**: Higher (tens of thousands msg/sec)

**Verdict:** Solid Cable handles most applications. Only ultra-high-traffic apps need Redis.

### Use Cases

**Perfect for Solid Cable:**
- Chat applications (100ms latency acceptable)
- Live notifications
- Presence indicators
- Dashboard updates
- Collaborative features

**Consider Redis if:**
- Sub-50ms latency required
- Millions of messages/second
- Millions of concurrent connections
- Already running Redis for caching

## Configuration Options

```yaml
production:
  adapter: solid_cable

  # Polling interval (seconds)
  polling_interval: 0.1  # 100ms (default)

  # Message retention (cleanup old messages)
  message_retention: 1.day  # Keep for debugging

  # Database connection pool
  # Uses ActiveRecord connection by default
```

### Tuning Polling Interval

```yaml
# Lower latency (more database load)
polling_interval: 0.05  # 50ms

# Higher latency (less database load)
polling_interval: 0.2   # 200ms
```

Balance latency needs with database capacity.

## Database Optimization

### Indexes

Ensure proper indexes exist:

```ruby
add_index :solid_cable_messages, :channel
add_index :solid_cable_messages, :created_at
```

Created automatically by installer.

### Vacuuming (PostgreSQL)

High-turnover table needs aggressive vacuuming:

```sql
ALTER TABLE solid_cable_messages
SET (autovacuum_vacuum_scale_factor = 0.01);
```

### Partitioning (Advanced)

For very high message volumes, partition by date:

```sql
CREATE TABLE solid_cable_messages (
  -- columns
) PARTITION BY RANGE (created_at);

CREATE TABLE solid_cable_messages_2024_01 PARTITION OF solid_cable_messages
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

## Message Retention

Messages are automatically deleted after retention period:

```ruby
# Keep messages for 1 day (default)
config.solid_cable.message_retention = 1.day

# Keep messages for 1 hour (less disk usage)
config.solid_cable.message_retention = 1.hour

# Keep messages for 1 week (better debugging)
config.solid_cable.message_retention = 1.week
```

Cleanup runs automatically via scheduled job.

### Manual Cleanup

```ruby
# Clean up messages older than 1 day
SolidCable::Message.where("created_at < ?", 1.day.ago).delete_all
```

## Monitoring

### Message Volume

```ruby
# Total messages
SolidCable::Message.count

# Messages in last hour
SolidCable::Message.where("created_at > ?", 1.hour.ago).count

# Messages by channel
SolidCable::Message.group(:channel).count
```

### Oldest Message

```ruby
# Check retention is working
oldest = SolidCable::Message.minimum(:created_at)
# Should be within message_retention period
```

### Database Size

```sql
-- PostgreSQL
SELECT pg_size_pretty(pg_total_relation_size('solid_cable_messages'));

-- MySQL
SELECT
  table_name AS "Table",
  ROUND(((data_length + index_length) / 1024 / 1024), 2) AS "Size (MB)"
FROM information_schema.TABLES
WHERE table_name = 'solid_cable_messages';
```

## Migration from Redis

### Before (Redis)

```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV['REDIS_URL'] %>
  channel_prefix: myapp_production
```

```ruby
# Gemfile
gem 'redis', '~> 5.0'
```

### After (Solid Cable)

```yaml
# config/cable.yml
production:
  adapter: solid_cable
  polling_interval: 0.1
  message_retention: 1.day
```

```ruby
# Gemfile
# Remove redis gem if only used for Action Cable
```

```bash
# Install Solid Cable
bin/rails solid_cable:install
bin/rails db:migrate

# Remove Redis from infrastructure
# Update Kamal/deployment config to remove Redis service
```

Application code stays identical—just the adapter changes.

## Deployment

### Database Connections

Solid Cable needs database connections:

```yaml
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } + 10 %>
  # +10 for Action Cable connections
```

### Separate Cable Server (Optional)

For high-traffic apps, run Action Cable on dedicated servers:

```yaml
# .kamal/deploy.yml
services:
  web:
    image: myapp

  cable:
    image: myapp
    cmd: bin/cable  # Separate process for WebSockets
    env:
      RAILS_ENV: production
```

### Health Checks

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def cable
    if ActionCable.server.connections.any?
      head :ok
    else
      head :service_unavailable
    end
  end
end
```

## Troubleshooting

### High Database Load

If polling creates too much load:

1. Increase `polling_interval` (reduce frequency)
2. Add database read replicas
3. Optimize `solid_cable_messages` indexes
4. Consider Redis for very high throughput

### Messages Not Delivering

Check:
1. Polling job running?
2. Messages being created in database?
3. Channels properly subscribed?
4. WebSocket connection established?

### Slow Broadcasts

Profile and optimize:

```ruby
# Use benchmarking
Benchmark.ms do
  ActionCable.server.broadcast("chat", { message: "Hello" })
end
```

If slow:
- Cache rendered partials
- Reduce message payload size
- Check database query performance

## Comparison: Solid Cable vs Redis

| Feature | Solid Cable | Redis |
|---------|-------------|-------|
| Latency | 50-150ms | <50ms |
| Throughput | Thousands msg/sec | Tens of thousands msg/sec |
| Setup | Database migration | Redis server |
| Deployment | No extra service | Separate service |
| Cost | Included | Additional hosting |
| Monitoring | SQL queries | Redis monitoring |
| Backup | Database backup | Separate Redis backup |

## When to Use What

### Use Solid Cable When:
- Building new Rails 8 app
- <100k concurrent connections
- 100-200ms latency acceptable
- Prefer simplicity
- Want to avoid Redis

### Use Redis When:
- Sub-50ms latency required
- Millions of messages/second
- Already running Redis
- Extreme scale requirements

For 95% of applications, Solid Cable is simpler and sufficient.

## Conclusion

Solid Cable embodies Rails philosophy:
- Integrated systems over distributed dependencies
- Simplicity over complexity
- Database as foundation
- Modern SQL capabilities

It lets you build real-time features without managing Redis, reducing infrastructure complexity while maintaining excellent performance for most applications.
