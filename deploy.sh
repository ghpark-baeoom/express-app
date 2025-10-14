#!/bin/bash

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
pm2 reload ecosystem.config.cjs

# 5. Show status
echo "✅ Deployment complete!"
pm2 status
pm2 logs --lines 10
