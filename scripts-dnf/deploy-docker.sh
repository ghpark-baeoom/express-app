#!/bin/bash

set -e

# 프로젝트 루트로 이동 (scripts-dnf 폴더의 상위 디렉토리)
cd "$(dirname "$0")/.."

echo "🚀 Starting Docker Compose deployment..."

# 1. Pull latest code
echo "📥 Pulling latest code from git..."
git pull origin main

# 2. Stop existing containers
echo "🛑 Stopping existing containers..."
docker compose down --remove-orphans

# 2.1. Clean up dangling networks
echo "🧹 Cleaning up unused networks..."
docker network prune -f

# 2.2. Reset nginx to blue environment
echo "🔄 Resetting nginx configuration to blue environment..."
cp nginx/conf.d/blue.conf nginx/conf.d/active.conf

# 3. Rebuild and restart containers with Bun
echo "🔨 Building new image and starting containers..."
docker compose up -d --build

# 3. Wait for container to be healthy
echo "⏳ Waiting for container to be healthy..."
sleep 5

# 4. Check status
echo "📊 Container status:"
docker compose ps

# 5. Show recent logs
echo ""
echo "📝 Recent logs:"
docker compose logs --tail 10

echo ""
echo "✅ Deployment completed successfully!"
