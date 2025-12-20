# Kamal Deployment: Complete Setup Guide

## Prerequisites

- Linux server (Ubuntu, Debian, etc.)
- SSH access to server
- Docker installed locally
- Git repository for your app

## Initial Setup

### 1. Install Kamal

```bash
gem install kamal
```

### 2. Initialize Kamal in Your Rails App

```bash
kamal init
```

Creates:
- `config/deploy.yml` - Main configuration
- `.kamal/secrets` - Secret environment variables
- `.kamal/hooks/` - Deployment hooks

### 3. Configure deploy.yml

```yaml
# config/deploy.yml
service: myapp
image: your-username/myapp

servers:
  web:
    hosts:
      - 192.168.1.100  # Your server IP

proxy:
  ssl: true
  host: myapp.com

registry:
  username: your-docker-hub-username
  password:
    - KAMAL_REGISTRY_PASSWORD

env:
  clear:
    DB_HOST: 192.168.1.100
  secret:
    - RAILS_MASTER_KEY

healthcheck:
  path: /up
  port: 3000
  interval: 10s
```

### 4. Set Up Secrets

```bash
# .kamal/secrets (not committed to git!)
KAMAL_REGISTRY_PASSWORD=$(cat ~/.docker/config.json | jq -r '.auths."https://index.docker.io/v1".auth' | base64 -d | cut -d: -f2)
RAILS_MASTER_KEY=$(cat config/master.key)
```

Or use Rails credentials:

```bash
KAMAL_REGISTRY_PASSWORD=$(rails credentials:fetch kamal.registry_password)
```

### 5. Prepare Server

```bash
# One-time setup
kamal setup
```

This:
- Installs Docker on server
- Sets up directories
- Configures proxy
- Obtains SSL certificate

### 6. Deploy

```bash
kamal deploy
```

Your app is live!

## Kamal Commands

```bash
# Initial setup
kamal setup

# Deploy new version
kamal deploy

# Deploy without building (use existing image)
kamal deploy --skip-build

# Rollback to previous version
kamal rollback

# View app logs
kamal app logs

# View proxy logs
kamal proxy logs

# SSH into container
kamal app exec -i bash

# Environment variables
kamal env

# Server details
kamal details

# Remove app from servers
kamal remove
```

## Multi-Environment Setup

```yaml
# config/deploy.yml
service: myapp
image: username/myapp

servers:
  web:
    hosts:
      - 192.168.1.100

# config/deploy.staging.yml
servers:
  web:
    hosts:
      - 192.168.1.200  # Staging server
```

Deploy to staging:

```bash
kamal deploy -d staging
```

## Database Setup

### Option 1: Database as Accessory

```yaml
accessories:
  db:
    image: postgres:16
    host: 192.168.1.100
    env:
      POSTGRES_DB: myapp_production
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD:
        - DB_PASSWORD
    directories:
      - data:/var/lib/postgresql/data
```

### Option 2: Managed Database

```yaml
env:
  clear:
    DB_HOST: db.provider.com
    DB_NAME: myapp_production
  secret:
    - DB_PASSWORD
```

Use RDS, Digital Ocean Databases, etc.

## Asset Serving

Rails 8 uses Propshaft + Thruster for asset serving.

### Propshaft Precompilation

```bash
# Runs automatically during kamal deploy
rails assets:precompile
```

### Thruster Configuration

```dockerfile
# Included in Rails 8 Dockerfile
CMD ["bin/thruster", "bin/rails", "server"]
```

Thruster handles:
- Static file serving with caching
- Gzip/Brotli compression
- X-Sendfile acceleration

## SSL/TLS

Kamal Proxy handles SSL automatically via Let's Encrypt:

```yaml
proxy:
  ssl: true
  host: myapp.com
```

Automatic certificate issuance and renewal.

## Health Checks

Kamal requires a health check endpoint:

```ruby
# config/routes.rb
get "up", to: "rails/health#show", as: :rails_health_check

# app/controllers/health_controller.rb (custom)
class HealthController < ApplicationController
  def show
    if database_healthy? && cache_healthy?
      head :ok
    else
      head :service_unavailable
    end
  end

  private

  def database_healthy?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue
    false
  end

  def cache_healthy?
    Rails.cache.write("health_check", "ok", expires_in: 1.minute)
    Rails.cache.read("health_check") == "ok"
  rescue
    false
  end
end
```

## Deployment Workflow

### 1. Prepare App

```bash
# Ensure tests pass
bin/rails test

# Ensure rubocop passes
bin/rubocop

# Ensure database is ready
bin/rails db:migrate
```

### 2. Commit Changes

```bash
git add .
git commit -m "feat: new feature"
git push origin main
```

### 3. Deploy

```bash
kamal deploy
```

### 4. Verify

```bash
# Check app logs
kamal app logs

# Check health
curl https://myapp.com/up

# SSH to container if needed
kamal app exec -i bash
```

## Monitoring and Logging

### Viewing Logs

```bash
# Application logs
kamal app logs
kamal app logs --since 10m
kamal app logs -f  # Follow

# Proxy logs
kamal proxy logs

# Specific service
kamal accessory logs db
```

### Log Aggregation

Configure log forwarding to external service:

```yaml
logging:
  driver: syslog
  options:
    syslog-address: "tcp://logs.papertrailapp.com:12345"
```

## Scaling

### Horizontal Scaling

Add more servers:

```yaml
servers:
  web:
    hosts:
      - 192.168.1.100
      - 192.168.1.101
      - 192.168.1.102
```

Kamal Proxy load balances across them.

### Separate Worker Servers

```yaml
servers:
  web:
    hosts:
      - 192.168.1.100
    labels:
      service: web

  worker:
    hosts:
      - 192.168.1.101
    cmd: bundle exec solid_queue:start
```

## Best Practices

1. **Test deploys on staging first**
2. **Use health checks** for safe rollouts
3. **Monitor logs** during deploy
4. **Keep secrets in `.kamal/secrets`** (not committed)
5. **Use managed databases** for production
6. **Set up monitoring** (error tracking, uptime)
7. **Configure backups** (database, uploaded files)
8. **Use CDN** for static assets
9. **Plan rollback strategy**
10. **Document deployment process**

Master Kamal and own your infrastructure without complexity.
