#!/bin/bash
# Kamal Deployment Hooks
#
# Place these scripts in .kamal/hooks/ and make them executable.
# chmod +x .kamal/hooks/*

# =============================================================================
# .kamal/hooks/pre-deploy
# Runs before deployment starts
# =============================================================================

echo "=== Pre-Deploy Hook ==="

# Run database backup before deploy
echo "Running database backup..."
# pg_dump -Fc myapp_production > /backups/pre-deploy-$(date +%Y%m%d-%H%M%S).dump

# Notify team of pending deployment
echo "Notifying team..."
# curl -X POST "$SLACK_WEBHOOK_URL" \
#   -H "Content-Type: application/json" \
#   -d '{"text": "🚀 Deployment starting for myapp"}'

echo "Pre-deploy checks complete"

# =============================================================================
# .kamal/hooks/post-deploy
# Runs after successful deployment
# =============================================================================

echo "=== Post-Deploy Hook ==="

# Clear CDN cache
echo "Clearing CDN cache..."
# curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/purge_cache" \
#   -H "Authorization: Bearer $CF_API_TOKEN" \
#   -d '{"purge_everything": true}'

# Notify team of successful deployment
echo "Notifying team of success..."
# curl -X POST "$SLACK_WEBHOOK_URL" \
#   -H "Content-Type: application/json" \
#   -d '{"text": "✅ Deployment complete for myapp"}'

# Warm up caches
echo "Warming up application..."
# curl -s https://myapp.com/up > /dev/null

echo "Post-deploy complete"

# =============================================================================
# .kamal/hooks/pre-build
# Runs before Docker image is built
# =============================================================================

echo "=== Pre-Build Hook ==="

# Ensure all tests pass before building
echo "Running tests..."
# bin/rails test || exit 1

# Run security audit
echo "Running security audit..."
# bundle exec bundler-audit check || exit 1

echo "Pre-build checks complete"
