1. Docker 설치 스크립트 파일 생성(install-docker.sh)

cat <<'EOF' > install-docker.sh
set -euo pipefail

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

---

2. 실행 권한 부여 및 실행
   chmod +x install-docker.sh
   bash ./install-docker.sh

---

3. 새 SSH로 다시 접속 후(그룹 반영) 확인
   docker --version
   docker compose version
   docker run --rm hello-world
