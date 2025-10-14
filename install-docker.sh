cat <<'EOF' > install-docker.sh
set -euo pipefail

# 0) 이전 흔적 정리
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose || true
sudo rm -f /etc/apt/keyrings/docker.asc
sudo mkdir -p /etc/apt/keyrings

# 1) 기본 패키지
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

# 2) GPG 키 저장(키링 방식)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 3) Docker 리포지토리 추가
ARCH=$(dpkg --print-architecture)
CODENAME=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# 4) 설치
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5) 데몬 활성화
sudo systemctl enable --now docker

# 6) (옵션) sudo 없이 사용
if id -nG "$USER" | grep -qvw docker; then
  sudo usermod -aG docker "$USER"
  echo "[INFO] docker 그룹에 현재 사용자 추가됨. 새 SSH 접속 후 반영됩니다."
fi

# 7) 버전 출력 (테스트)
docker --version
docker compose version
EOF