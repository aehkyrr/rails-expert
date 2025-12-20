# Kamal Philosophy: Own Your Infrastructure

## Introduction

Rails 8 includes **Kamal 2**, a deployment tool that embodies a radical philosophy: you should own your infrastructure. No PaaS lock-in. No Kubernetes complexity. Just Docker containers on Linux servers you control.

Kamal represents DHH's vision for deployment: simple, powerful, and independent. One command deploys your entire application with zero downtime.

## The Problem Kamal Solves

### PaaS Lock-in

Platform-as-a-Service providers (Heroku, Render, Fly.io) offer convenience but create dependencies:

- **Pricing control**: They set prices, you pay
- **Feature limitations**: You get what they offer
- **Migration difficulty**: Moving away is painful
- **Vendor risk**: Their outages are your outages

Kamal gives you the convenience of PaaS with the control of your own servers.

### Kubernetes Complexity

Kubernetes is powerful but complex:

- Steep learning curve
- Significant operational overhead
- Overkill for most applications
- Requires dedicated expertise
- Expensive in time and money

Kamal provides container orchestration without the complexity.

### Traditional Deployments

Manual or Capistrano-style deployments have issues:

- Server state drift
- Inconsistent environments
- Downtime during deploys
- Complex rollback procedures
- Ruby version management headaches

Kamal uses Docker for consistency and provides zero-downtime deploys.

## Kamal's Core Philosophy

### Own Your Infrastructure

Kamal encourages running on commodity Linux servers:

- **Cloud VPS**: Hetzner, DigitalOcean, Linode, AWS EC2
- **Bare metal**: Dedicated servers for maximum performance
- **Hybrid**: Mix and match as needed

You choose providers. You control costs. You maintain independence.

### Docker for Consistency

Kamal uses Docker containers:

```dockerfile
# Dockerfile
FROM ruby:3.3
WORKDIR /rails
COPY Gemfile* ./
RUN bundle install
COPY . .
RUN bundle exec rails assets:precompile
CMD ["./bin/thrust", "./bin/rails", "server"]
```

The same container runs everywhere:

- Local development
- CI/CD pipelines
- Production servers

No more "works on my machine" problems.

### Zero-Downtime Deploys

Kamal orchestrates deployments without downtime:

1. Build new container image
2. Push to registry (or transfer directly)
3. Start new containers on servers
4. Health check new containers
5. Switch traffic to new containers
6. Stop old containers

Users never see an error page.

### Simple Configuration

Kamal configuration is straightforward:

```yaml
# config/deploy.yml
service: myapp

image: myregistry/myapp

servers:
  web:
    - 192.168.1.1
    - 192.168.1.2
  job:
    hosts:
      - 192.168.1.3
    cmd: bin/jobs

proxy:
  ssl: true
  host: myapp.com

env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
```

Compare this to Kubernetes YAML files spanning hundreds of lines.

## Kamal 2 Architecture

### Kamal Proxy

Kamal 2 replaced Traefik with **Kamal Proxy**, a purpose-built reverse proxy:

- **Faster**: Optimized for Kamal's specific use case
- **Simpler**: No Traefik configuration complexity
- **Integrated**: Designed specifically for Kamal deployments
- **Automatic SSL**: Let's Encrypt certificates handled automatically

Kamal Proxy handles:

- Request routing to containers
- Health checking
- SSL termination
- Zero-downtime container switching

### Thruster Integration

Rails 8's Dockerfile includes **Thruster**, a Rust-based HTTP accelerator:

```dockerfile
CMD ["./bin/thrust", "./bin/rails", "server"]
```

Thruster sits between Kamal Proxy and Puma, providing:

- X-Sendfile acceleration for file downloads
- Gzip/Brotli compression
- Asset caching headers
- Request buffering

Production performance by default, no complex reverse proxy setup.

### Registry-Free Deploys (Rails 8.1+)

Traditional container deployment requires a registry:

1. Build image locally
2. Push to Docker Hub/ECR/GCR
3. Servers pull from registry

Rails 8.1+ supports registry-free deploys:

1. Build image locally
2. Transfer directly to servers via SSH

Benefits:

- No registry costs
- No registry configuration
- Simpler setup for small teams
- Works behind firewalls

## Deployment Workflow

### Initial Setup

```bash
# Install Kamal
gem install kamal

# Initialize configuration
kamal init

# Set up servers (installs Docker, creates directories)
kamal server bootstrap
```

### Daily Deploys

```bash
# Deploy everything
kamal deploy

# Or deploy just web servers
kamal deploy --roles=web
```

One command. Zero downtime. Automatic rollback on failure.

### Rollbacks

```bash
# Roll back to previous version
kamal rollback

# Roll back to specific version
kamal rollback v1.2.3
```

Container images are immutable. Rollback is instant.

### Monitoring

```bash
# View logs
kamal app logs

# View logs from specific server
kamal app logs --hosts=192.168.1.1

# Check container status
kamal app details
```

### Maintenance

```bash
# Run Rails console on production
kamal app exec -i 'bin/rails console'

# Run one-off commands
kamal app exec 'bin/rails db:migrate'

# Restart application
kamal app boot
```

## Self-Sufficiency Philosophy

Kamal embodies Rails' one-person framework philosophy for deployment:

### Small Teams Can Deploy

A single developer can:

- Set up production infrastructure
- Configure CI/CD
- Deploy updates
- Handle rollbacks
- Debug production issues

No dedicated DevOps team required.

### Low Operational Burden

Kamal minimizes ongoing work:

- Docker handles environment consistency
- Kamal Proxy manages routing
- Thruster optimizes performance
- Health checks catch failures

You focus on building features, not managing infrastructure.

### Cost Control

Own your infrastructure, control your costs:

- **$5-20/month VPS**: Handles significant traffic
- **No per-dyno pricing**: Scale horizontally affordably
- **No bandwidth surprises**: Predictable pricing
- **No vendor markups**: Pay infrastructure cost only

## Comparison with Alternatives

### vs. Heroku

| Aspect | Heroku | Kamal |
|--------|--------|-------|
| Setup time | Minutes | Hours (first time) |
| Monthly cost | $25-$250+/dyno | $5-$50/server |
| Vendor lock-in | High | None |
| Customization | Limited | Full |
| Scaling control | Platform-managed | You decide |
| Exit strategy | Difficult | Switch servers |

### vs. Kubernetes

| Aspect | Kubernetes | Kamal |
|--------|------------|-------|
| Learning curve | Steep | Gentle |
| Operational overhead | High | Low |
| Team size needed | DevOps team | One developer |
| Scaling | Automatic | Manual (simpler) |
| Cost | Expensive | Affordable |
| Features | Extensive | Focused |

### vs. Capistrano

| Aspect | Capistrano | Kamal |
|--------|------------|-------|
| Environment consistency | Server-dependent | Docker-consistent |
| Zero-downtime | Complex | Built-in |
| Rollback | Symlink juggling | Container switching |
| Ruby version | rbenv/rvm complexity | Container-defined |
| Asset compilation | On server | In build |

## Best Practices

### Server Sizing

Start small, scale when needed:

```yaml
# Start with one server
servers:
  web:
    - 192.168.1.1
```

Add servers as traffic grows:

```yaml
# Scale horizontally
servers:
  web:
    - 192.168.1.1
    - 192.168.1.2
    - 192.168.1.3
```

### Database Hosting

Options for database:

- **Same server**: Simple, fine for small apps
- **Managed database**: RDS, Managed PostgreSQL
- **Separate server**: Full control, more work

Start simple, upgrade when needed.

### Secrets Management

```yaml
# config/deploy.yml
env:
  clear:
    RAILS_ENV: production
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL
    - REDIS_URL
```

Secrets stored in `.kamal/secrets`:

```bash
# .kamal/secrets
RAILS_MASTER_KEY=your_master_key
DATABASE_URL=postgres://...
```

### Health Checks

Kamal checks container health before switching traffic:

```yaml
# config/deploy.yml
healthcheck:
  path: /up
  port: 3000
  max_attempts: 10
  interval: 1s
```

Rails 8 includes a `/up` endpoint by default.

## Conclusion

Kamal represents Rails' deployment philosophy:

- **Simple**: One command deploys everything
- **Powerful**: Zero-downtime, instant rollback
- **Independent**: Own your infrastructure
- **Affordable**: Control your costs
- **Self-sufficient**: One developer can manage production

Stop paying the PaaS tax. Stop fighting Kubernetes complexity. Deploy Rails applications the Rails way: simply, powerfully, independently.

```bash
kamal deploy
```

That's it. That's the philosophy in action.
