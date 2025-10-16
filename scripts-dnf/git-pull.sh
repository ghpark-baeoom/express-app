#!/bin/bash

# 프로젝트 루트로 이동 (scripts-dnf 폴더의 상위 디렉토리)
cd "$(dirname "$0")/.."

echo "📥 Pulling latest code from git..."
git pull origin main
