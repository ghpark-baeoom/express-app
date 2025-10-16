#!/bin/bash

set -e

# 프로젝트 루트 디렉토리로 이동 (scripts-dnf의 상위 디렉토리)
cd "$(dirname "$0")/.."

echo "🧹 Cleaning up Express app Docker environment..."
echo ""

# 1. Stop and remove all containers (including profiles)
echo "🛑 Stopping and removing all containers..."
docker compose --profile green down --remove-orphans

# 2. Remove dangling images
echo "🗑️  Removing dangling images..."
docker image prune -f

# 3. Show remaining images
echo ""
echo "📊 Remaining images:"
docker images | grep -E "express-app|nginx|REPOSITORY"

echo ""
echo "✅ Cleanup completed!"
