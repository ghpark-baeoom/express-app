#!/bin/bash

# Amazon Linux 2023에서 Docker 설치 스크립트

# 1) 시스템 업데이트
sudo dnf update -y

# 2) Docker 설치
sudo dnf install -y docker

# 3) Docker 서비스 시작 및 자동 시작 설정
sudo systemctl start docker
sudo systemctl enable docker

# 4) ec2-user를 docker 그룹에 추가 (sudo 없이 사용)
if id -nG "$USER" | grep -qvw docker; then
  sudo usermod -aG docker "$USER"
  echo "[INFO] docker 그룹에 현재 사용자 추가됨. 새 SSH 접속 후 반영됩니다."
fi

# 5) Docker Compose 설치 (Docker CLI plugin)
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

# 6) 버전 출력 (테스트)
docker --version
docker compose version

echo ""
echo "✅ Docker 설치 완료!"
echo "⚠️  새 SSH 세션에서 'docker' 명령을 sudo 없이 사용할 수 있습니다."
