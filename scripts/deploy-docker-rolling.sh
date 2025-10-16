#!/bin/bash

set -e

# 프로젝트 루트 디렉토리로 이동 (scripts의 상위 디렉토리)
cd "$(dirname "$0")/.."

echo "🚀 Starting Express app Blue-Green Rolling Deployment..."

# 1. Detect current active environment
if [ ! -f "nginx/conf.d/active.conf" ]; then
    echo "❌ Error: nginx/conf.d/active.conf not found!"
    echo "Creating initial active.conf (Blue)..."
    cp nginx/conf.d/blue.conf nginx/conf.d/active.conf
fi

ACTIVE_LINE=$(cat nginx/conf.d/active.conf)

if echo "$ACTIVE_LINE" | grep -q "express-app-blue"; then
    CURRENT="blue"
    NEXT="green"
    CURRENT_PORT=3001
    NEXT_PORT=3002
elif echo "$ACTIVE_LINE" | grep -q "express-app-green"; then
    CURRENT="green"
    NEXT="blue"
    CURRENT_PORT=3002
    NEXT_PORT=3001
else
    echo "❌ Error: Unable to determine active environment from active.conf"
    exit 1
fi

echo "📊 Current active environment: $CURRENT (port $CURRENT_PORT)"
echo "🎯 Deploying to: $NEXT (port $NEXT_PORT)"
echo ""

# 2. Pull latest code
echo "📥 Pulling latest code from git..."
git pull origin main
echo ""

# 3. Build new image for next environment
echo "🔨 Building new Express app image for $NEXT environment..."
docker compose build express-app-$NEXT
echo ""

# 4. Start next environment
echo "🚀 Starting $NEXT environment (port $NEXT_PORT)..."
if [ "$NEXT" == "green" ]; then
    docker compose --profile green up -d express-app-green
else
    docker compose up -d express-app-blue
fi
echo ""

# 5. Health check for next environment
echo "⏳ Waiting for $NEXT environment to be healthy..."
MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:$NEXT_PORT/health > /dev/null 2>&1; then
        echo "✅ $NEXT environment is healthy!"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo "❌ $NEXT environment failed health check after $MAX_RETRIES attempts!"
        echo "Rolling back: stopping $NEXT environment..."
        docker compose stop express-app-$NEXT
        echo "📊 Current status:"
        docker compose ps
        exit 1
    fi

    echo "Attempt $RETRY_COUNT/$MAX_RETRIES - waiting..."
    sleep 2
done
echo ""

# 6. Switch Nginx traffic to next environment
echo "🔄 Switching Nginx traffic from $CURRENT to $NEXT..."
cp nginx/conf.d/$NEXT.conf nginx/conf.d/active.conf

# Reload Nginx configuration
docker compose exec nginx nginx -s reload

if [ $? -eq 0 ]; then
    echo "✅ Nginx successfully switched to $NEXT environment"
else
    echo "❌ Failed to reload Nginx!"
    echo "Rolling back: restoring $CURRENT as active..."
    cp nginx/conf.d/$CURRENT.conf nginx/conf.d/active.conf
    docker compose exec nginx nginx -s reload
    exit 1
fi
echo ""

# 7. Wait a bit to ensure traffic is flowing to next environment
echo "⏳ Waiting 3 seconds to ensure traffic is stable..."
sleep 3

# 8. Stop current (old) environment
echo "🛑 Stopping $CURRENT environment (port $CURRENT_PORT)..."
docker compose stop express-app-$CURRENT
echo ""

# 9. Remove stopped container and clean up dangling images
echo "🗑️  Removing stopped $CURRENT container..."
docker compose rm -f express-app-$CURRENT
echo "🧹 Cleaning up dangling images..."
docker image prune -f
echo ""

# 10. Show final status
echo "📊 Final container status:"
docker compose ps
echo ""

echo "📝 Recent logs from $NEXT environment:"
docker compose logs --tail 10 express-app-$NEXT
echo ""

echo "✅ Blue-Green rolling deployment completed successfully!"
echo "🎉 Active environment: $NEXT (port $NEXT_PORT)"
echo "💡 Access your app at: http://localhost:3000"
