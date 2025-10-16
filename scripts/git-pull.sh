#!/bin/bash

# 스크립트가 있는 디렉토리로 이동
cd "$(dirname "$0")"

echo "📥 Pulling latest code from git..."
git pull origin main