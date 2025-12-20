# Production Deployment Checklist

A comprehensive checklist for deploying Rails 8 applications to production with Kamal.

## Pre-Deployment Checks

### Application Readiness

- [ ] All tests passing (`bin/rails test && bin/rails test:system`)
- [ ] No critical security vulnerabilities (`bin/bundler-audit check`)
- [ ] Linting passes (`bin/rubocop`)
- [ ] Database migrations are reversible or have been tested
- [ ] Environment-specific configuration verified

### Credentials and Secrets

- [ ] `RAILS_MASTER_KEY` securely stored (not in version control)
- [ ] Production credentials configured (`rails credentials:edit --environment production`)
- [ ] All required secrets present in `.kamal/secrets`
- [ ] API keys and tokens are production-ready (not test/sandbox)
- [ ] Database credentials configured

### Infrastructure

- [ ] Server meets minimum requirements (Ubuntu LTS, 1GB+ RAM)
- [ ] SSH access configured and tested
- [ ] Firewall rules allow ports 80, 443, and SSH
- [ ] DNS records point to server IP (if using domain)
- [ ] Docker registry access configured (or using local registry)

## Security Hardening

### Rails Configuration

```ruby
# config/environments/production.rb
config.force_ssl = true
config.ssl_options = { hsts: { subdomains: true, preload: true } }
config.action_dispatch.default_headers.merge!(
  'X-Frame-Options' => 'SAMEORIGIN',
  'X-Content-Type-Options' => 'nosniff',
  'X-XSS-Protection' => '1; mode=block'
)
```

### Server Security

- [ ] SSH key-based authentication only (password auth disabled)
- [ ] Fail2ban or similar intrusion prevention installed
- [ ] Unattended security updates enabled
- [ ] Non-root user for deployments
- [ ] UFW/iptables configured

### Application Security

- [ ] CSRF protection enabled (default in Rails)
- [ ] Strong parameters used in all controllers
- [ ] SQL injection prevention (use parameterized queries)
- [ ] XSS prevention (escape user input in views)
- [ ] Secure cookies configured

## Performance Optimization

### Rails Configuration

```ruby
# config/environments/production.rb
config.cache_classes = true
config.eager_load = true
config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
config.assets.compile = false
config.assets.digest = true
config.log_level = :info
```

### Database

- [ ] Connection pooling configured appropriately
- [ ] Indexes exist for frequently queried columns
- [ ] N+1 queries identified and resolved
- [ ] Database vacuum/analyze scheduled (PostgreSQL)

### Caching

- [ ] Solid Cache configured for production
- [ ] Fragment caching implemented for expensive views
- [ ] Russian doll caching for nested resources
- [ ] Cache keys include timestamps for invalidation

### Assets

- [ ] Assets precompiled (`rails assets:precompile`)
- [ ] Thruster configured for compression
- [ ] CDN configured for static assets (optional)
- [ ] Image optimization applied

## Monitoring Setup

### Error Tracking

- [ ] Error tracking service configured (Sentry, Honeybadger, etc.)
- [ ] Error notifications sent to appropriate channels
- [ ] Source maps uploaded for JavaScript errors

### Application Performance Monitoring

- [ ] APM service configured (optional but recommended)
- [ ] Key transactions identified
- [ ] Performance baselines established

### Health Checks

```ruby
# config/routes.rb
get "up", to: "rails/health#show", as: :rails_health_check

# Custom health check (optional)
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    checks = {
      database: database_healthy?,
      cache: cache_healthy?,
      disk: disk_healthy?
    }
    status = checks.values.all? ? :ok : :service_unavailable
    render json: { status: status, checks: checks }, status: status
  end

  private

  def database_healthy?
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  rescue StandardError
    false
  end

  def cache_healthy?
    Rails.cache.write("health", "ok", expires_in: 1.minute)
    Rails.cache.read("health") == "ok"
  rescue StandardError
    false
  end

  def disk_healthy?
    stat = Sys::Filesystem.stat(Rails.root)
    (stat.bytes_free.to_f / stat.bytes_total) > 0.1 # 10% free
  rescue StandardError
    true # Skip if sys-filesystem gem not available
  end
end
```

### Logging

- [ ] Log aggregation configured (Papertrail, Logtail, etc.)
- [ ] Log level appropriate for production (`:info`)
- [ ] Sensitive data filtered from logs
- [ ] Log rotation configured

### Uptime Monitoring

- [ ] External uptime monitor configured
- [ ] Alert thresholds defined
- [ ] On-call rotation established (if applicable)

## Backup Configuration

### Database Backups

- [ ] Automated daily backups configured
- [ ] Backup retention policy defined (e.g., 30 days)
- [ ] Backup restoration tested
- [ ] Off-site backup storage configured

### File Backups

- [ ] Active Storage files backed up (if using local disk)
- [ ] Credentials backup stored securely
- [ ] Configuration files backed up

### Backup Commands

```bash
# PostgreSQL backup
pg_dump -Fc myapp_production > backup.dump

# Restore
pg_restore -d myapp_production backup.dump

# With Kamal accessory
kamal accessory exec db -- pg_dump -U myapp myapp_production > backup.sql
```

## Post-Deployment Verification

### Immediate Checks

- [ ] Application responds on production URL
- [ ] Health check endpoint returns 200
- [ ] Login/authentication works
- [ ] Critical user flows tested
- [ ] Background jobs processing

### Monitoring Checks

- [ ] No new errors in error tracker
- [ ] Response times within acceptable range
- [ ] Database connections stable
- [ ] Memory usage normal

## Rollback Plan

### Kamal Rollback

```bash
# View deployment history
kamal app version

# Rollback to previous version
kamal rollback

# Rollback to specific version
kamal rollback --version abc123
```

### Database Rollback

```bash
# If migration caused issues
kamal app exec -- bin/rails db:rollback STEP=1
```

### Emergency Procedures

1. **Identify the issue** - Check logs, error tracker, monitoring
2. **Assess severity** - Is it blocking all users or a subset?
3. **Communicate** - Notify stakeholders if needed
4. **Rollback if needed** - `kamal rollback`
5. **Investigate** - Reproduce in staging, identify root cause
6. **Fix forward** - Deploy fix once identified and tested

## Deployment Commands Reference

```bash
# First-time setup
kamal setup

# Standard deploy
kamal deploy

# Deploy without building (use existing image)
kamal deploy --skip-build

# View logs
kamal app logs -f

# SSH into container
kamal app exec -i bash

# Rails console
kamal console

# Run migrations manually
kamal app exec -- bin/rails db:migrate

# Check deployment status
kamal details
```

## Maintenance Mode

```bash
# Enable maintenance mode (Kamal 2+)
kamal proxy stop

# Disable maintenance mode
kamal proxy boot
```

For custom maintenance pages, configure in Kamal Proxy settings.
