#!/bin/bash

set -e

echo "🚀 Starting Docker deployment..."

# 환경 변수 확인
if [ -z "$ECR_REGISTRY" ] || [ -z "$ECR_REPOSITORY" ]; then
  echo "❌ Error: ECR_REGISTRY and ECR_REPOSITORY must be set"
  exit 1
fi

# 이미지 태그 설정 (기본값: latest)
IMAGE_TAG=${IMAGE_TAG:-latest}
IMAGE_URI="$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG"

echo "📥 Pulling Docker image from ECR..."
echo "Image: $IMAGE_URI"

# 최신 이미지 pull
docker pull $IMAGE_URI

echo "🔄 Stopping existing container..."
# 기존 컨테이너 중지 및 삭제 (에러 무시)
docker stop express-app 2>/dev/null || true
docker rm express-app 2>/dev/null || true

echo "🚀 Starting new container..."
# 새 컨테이너 시작
docker run -d \
  --name express-app \
  --restart unless-stopped \
  -p 3000:3000 \
  --env-file ~/express-app/.env \
  $IMAGE_URI

# 컨테이너 시작 대기
echo "⏳ Waiting for container to be ready..."
sleep 5

# 헬스체크
echo "🏥 Health check..."
for i in {1..30}; do
  if docker exec express-app wget -qO- http://localhost:3000/health > /dev/null 2>&1; then
    echo "✅ Container is healthy!"
    break
  fi

  if [ $i -eq 30 ]; then
    echo "❌ Health check failed"
    docker logs express-app --tail 50
    exit 1
  fi

  echo "Waiting... ($i/30)"
  sleep 2
done

# 컨테이너 상태 확인
echo ""
echo "📊 Container status:"
docker ps --filter name=express-app

echo ""
echo "📝 Recent logs:"
docker logs express-app --tail 10

echo ""
echo "✅ Deployment completed successfully!"
