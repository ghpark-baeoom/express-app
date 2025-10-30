#!/bin/bash

# 프로젝트 루트로 이동 (scripts-dnf 폴더의 상위 디렉토리)
cd "$(dirname "$0")/.."

echo "🚀 Starting deployment..."

# 1. Pull latest code
echo "📥 Pulling latest code from git..."
git pull origin main

# 2. Install dependencies
echo "📦 Installing dependencies..."
npm ci

# 3. Build TypeScript
echo "🔨 Building TypeScript..."
npm run build

# 4. Reload PM2 (zero-downtime)
echo "♻️  Reloading PM2 processes..."
pm2 reload ecosystem.config.js --update-env
# pm2 gracefulReload ecosystem.config.js --update-env (gracefulReload은 무중단 재시작)

# 5. Show status
echo "✅ Deployment complete!"
pm2 status
pm2 logs --lines 10
