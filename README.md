# Express App

Node.js + Express + TypeScript로 구성된 웹 애플리케이션입니다.

## 기술 스택

- **Runtime**: Node.js 22
- **Framework**: Express 5
- **Language**: TypeScript
- **Process Manager**: PM2
- **Build Tool**: TSC (TypeScript Compiler)
- **Dev Tool**: tsx

## 프로젝트 구조

```
express-app/
├── dist/                       # 빌드된 JavaScript 파일
├── nginx/                      # Nginx 설정 파일 (Blue-Green 배포용)
│   ├── nginx.conf             # Nginx 메인 설정
│   └── conf.d/                # Upstream 설정
│       ├── active.conf        # 현재 활성 환경 (blue/green)
│       ├── blue.conf          # Blue 환경 upstream
│       └── green.conf         # Green 환경 upstream
├── scripts/                    # Ubuntu/Debian 배포 스크립트 (apt)
│   ├── git-pull.sh            # Git 최신 코드 가져오기
│   ├── install-docker.sh      # Docker 설치 (Ubuntu)
│   ├── manual-deploy-pm2.sh   # PM2 무중단 배포
│   ├── manual-deploy-docker.sh # Docker Compose 배포
│   └── deploy-github-actions.sh # GitHub Actions용 ECR 배포
├── scripts-dnf/                # Amazon Linux 2023 배포 스크립트 (dnf)
│   ├── git-pull.sh            # Git 최신 코드 가져오기
│   ├── install-docker.sh      # Docker 설치 (AL2023)
│   ├── deploy-docker-rolling.sh # Blue-Green 무중단 배포 ⭐
│   ├── manual-deploy-pm2.sh   # PM2 무중단 배포
│   ├── manual-deploy-docker.sh # Docker Compose 배포
│   └── deploy-github-actions.sh # GitHub Actions용 ECR 배포
├── server.ts                   # 메인 서버 파일
├── ecosystem.config.cjs        # PM2 설정 파일
├── docker-compose.yml          # Docker Compose 설정 (Blue-Green)
├── Dockerfile                  # Docker 이미지 빌드 설정
├── .env                        # 환경 변수
├── tsconfig.json               # TypeScript 설정
├── package.json                # 프로젝트 의존성
└── README.md
```

## 환경 변수 (.env)

```bash
PORT=3000
NODE_ENV=production
```

## 로컬 개발

### 설치

```bash
npm install
```

### 개발 서버 실행

```bash
npm run dev
```

서버가 `http://localhost:3000`에서 실행됩니다.

### 빌드

```bash
npm run build
```

빌드 결과물은 `dist/` 폴더에 생성됩니다.

## 프로덕션 배포 (PM2)

### 1. 최초 배포

```bash
# 1. 저장소 클론
git clone https://github.com/ghpark-baeoom/express-app.git
cd express-app

# 2. .env 파일 생성 (프로젝트 루트에)
cat > .env << 'EOF'
PORT=3000
NODE_ENV=production
EOF

# 3. 의존성 설치 (빌드를 위해 devDependencies 포함)
npm ci

# 4. TypeScript 빌드
npm run build

# 5. (선택사항) Port 80 사용 시 Node.js에 권한 부여
sudo setcap 'cap_net_bind_service=+ep' $(which node)

# 6. PM2로 앱 실행
pm2 start ecosystem.config.cjs

# 7. 로그 확인 (정상 작동 확인)
pm2 logs

# 8. 현재 프로세스 목록 저장
pm2 save

# 9. 서버 재부팅 시 자동 시작 설정
pm2 startup
# 위 명령어 실행 후 출력되는 명령어를 복사하여 실행 (sudo 권한 필요)
```

### 2. 무중단 재배포

#### Ubuntu/Debian (apt 기반)
```bash
./scripts/manual-deploy-pm2.sh
```

#### Amazon Linux 2023 (dnf 기반)
```bash
./scripts-dnf/manual-deploy-pm2.sh
```

#### 수동 배포
```bash
# 1. 최신 코드 받기
git pull origin main

# 2. 의존성 설치
npm ci

# 3. 빌드
npm run build

# 4. 무중단 재시작 (⭐ 핵심)
pm2 reload ecosystem.config.cjs
```

### 3. PM2 명령어

```bash
# 프로세스 상태 확인
pm2 status

# 로그 실시간 확인
pm2 logs

# 특정 앱 로그만 확인
pm2 logs express-app

# 최근 100줄만 보기
pm2 logs --lines 100

# 프로세스 중지
pm2 stop express-app

# 프로세스 재시작 (다운타임 발생)
pm2 restart express-app

# 무중단 재시작
pm2 reload express-app

# 프로세스 삭제
pm2 delete express-app

# 모든 프로세스 삭제
pm2 delete all

# PM2 모니터링
pm2 monit
```

### 4. PM2 초기화

PM2가 이상하게 작동할 때:

```bash
# 방법 1: 모든 프로세스 삭제 (PM2 데몬 유지)
pm2 delete all

# 방법 2: PM2 완전 종료 (데몬까지 종료)
pm2 kill
```

**차이점:**

- `pm2 delete all`: 앱만 삭제, PM2 데몬은 유지
- `pm2 kill`: PM2 자체를 완전히 종료 (전체 초기화)

## 무중단 배포 원리

PM2 클러스터 모드와 `wait_ready` 시그널을 사용하여 안전한 무중단 배포를 구현합니다:

### 1. PM2 설정 (ecosystem.config.cjs)
```javascript
{
  instances: 2,           // 2개 인스턴스 실행
  exec_mode: "cluster",   // 클러스터 모드
  wait_ready: true,       // ready 신호 대기
  listen_timeout: 10000   // 최대 10초 대기
}
```

### 2. 서버 시작 시 ready 신호 전송 (server.ts)
```javascript
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT} ✅ [PID: ${process.pid}]`);

  // PM2에 ready 신호 전송
  if (process.send) {
    process.send("ready");
  }
});
```

### 3. 무중단 배포 흐름
**`pm2 reload` 사용 시:**
1. Instance 1 시작 대기 (Instance 2가 요청 처리)
2. Instance 1이 `ready` 신호 전송
3. Instance 1 준비 완료 → Instance 2 종료
4. Instance 2 시작 대기 (Instance 1이 요청 처리)
5. Instance 2가 `ready` 신호 전송
6. **다운타임 0초!**

**주의:**
- `pm2 restart`: 모든 인스턴스 동시 재시작 → 다운타임 발생
- `pm2 reload`: 하나씩 순차 재시작 + ready 신호 확인 → 무중단 ⭐

## Docker 배포

### Docker 설치

#### Ubuntu/Debian
```bash
./scripts/install-docker.sh
```

#### Amazon Linux 2023
```bash
./scripts-dnf/install-docker.sh
```

### 빌드 및 실행

```bash
# Docker 이미지 빌드
docker build -t express-app .

# 컨테이너 실행
docker run -p 3000:3000 --env-file .env express-app

# 또는 환경변수 직접 지정
docker run -p 8080:8080 -e PORT=8080 express-app
```

### Docker Compose 무중단 배포

#### Ubuntu/Debian
```bash
./scripts/manual-deploy-docker.sh
```

#### Amazon Linux 2023
```bash
./scripts-dnf/manual-deploy-docker.sh
```

#### 수동 배포
```bash
# 빌드 및 시작
docker compose up -d

# 재빌드 후 시작
docker compose up -d --build

# 로그 확인
docker compose logs -f

# 중지 및 삭제
docker compose down
```

## Blue-Green Rolling Deployment (무중단 배포)

Blue-Green 배포는 Nginx 리버스 프록시를 통해 두 개의 독립적인 환경(Blue/Green) 간 트래픽을 전환하여 완전한 무중단 배포를 구현합니다.

### 아키텍처

```
                  ┌─────────────┐
                  │   Nginx     │ :3000 (외부 접근)
                  │  (Proxy)    │
                  └──────┬──────┘
                         │
           ┌─────────────┴─────────────┐
           │ active.conf (blue/green)  │
           └─────────────┬─────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
   ┌────▼────┐                       ┌────▼────┐
   │  Blue   │ :3001                 │  Green  │ :3002
   │Container│ (always running)      │Container│ (deploy only)
   └─────────┘                       └─────────┘
```

### 특징

- **완전 무중단**: Nginx가 트래픽을 전환하는 동안 서비스 중단 없음
- **빠른 롤백**: active.conf만 변경하면 이전 환경으로 즉시 복구
- **안전한 배포**: 새 환경의 health check 통과 후에만 트래픽 전환
- **리소스 효율**: 배포 시에만 두 환경이 동시 실행

### 배포 프로세스

```bash
# Amazon Linux 2023
./scripts-dnf/deploy-docker-rolling.sh
```

#### 배포 흐름

1. **현재 활성 환경 감지** (active.conf 분석)
   - Blue가 활성 → Green으로 배포
   - Green이 활성 → Blue로 배포

2. **새 환경 시작**
   - 최신 코드 pull
   - Docker 이미지 빌드
   - 컨테이너 시작 (기존 환경은 계속 실행)

3. **Health Check**
   - 새 환경이 정상 작동할 때까지 최대 10회 재시도
   - 실패 시 자동 롤백 (새 환경 중단)

4. **트래픽 전환**
   - `active.conf`를 새 환경으로 변경
   - Nginx 설정 reload (nginx -s reload)
   - 실패 시 자동 롤백 (이전 환경으로 복구)

5. **이전 환경 정리**
   - 3초 대기 후 이전 환경 중단
   - Dangling 이미지 정리

### Docker Compose 설정

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "3000:80"  # 외부 접근
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
    depends_on:
      - express-app-blue

  express-app-blue:
    container_name: express-app-blue
    ports:
      - "3001:3000"  # 직접 접근용 (디버깅)
    # Blue는 항상 실행 (profile 없음)

  express-app-green:
    container_name: express-app-green
    ports:
      - "3002:3000"  # 직접 접근용 (디버깅)
    profiles:
      - green  # 배포 시에만 시작
```

### Nginx 설정 파일

```nginx
# nginx/conf.d/blue.conf
server express-app-blue:3000;

# nginx/conf.d/green.conf
server express-app-green:3000;

# nginx/conf.d/active.conf (동적으로 변경)
server express-app-blue:3000;  # 또는 green
```

### 직접 접근 (디버깅)

```bash
# Nginx를 통한 접근 (실제 사용자 경로)
curl http://localhost:3000/health

# Blue 환경 직접 접근
curl http://localhost:3001/health

# Green 환경 직접 접근 (실행 중일 때만)
curl http://localhost:3002/health
```

### 수동 롤백

문제 발견 시 즉시 이전 환경으로 롤백:

```bash
# 현재 active.conf 확인
cat nginx/conf.d/active.conf

# Blue로 롤백
cp nginx/conf.d/blue.conf nginx/conf.d/active.conf
docker compose exec nginx nginx -s reload

# Green으로 롤백
cp nginx/conf.d/green.conf nginx/conf.d/active.conf
docker compose exec nginx nginx -s reload
```

### 장애 대응

#### Nginx 상태 확인
```bash
# Nginx 로그 확인
docker compose logs nginx

# Nginx 설정 테스트
docker compose exec nginx nginx -t

# Nginx 재시작
docker compose restart nginx
```

#### 환경별 로그 확인
```bash
# Blue 환경 로그
docker compose logs express-app-blue

# Green 환경 로그
docker compose logs --tail 50 express-app-green

# 실시간 로그
docker compose logs -f express-app-blue
```

### PM2 vs Blue-Green 비교

| 특징 | PM2 Reload | Blue-Green (Docker) |
|------|------------|---------------------|
| 무중단 배포 | ✅ 지원 | ✅ 지원 |
| 롤백 속도 | 재배포 필요 | 즉시 (설정 변경) |
| 리소스 사용 | 낮음 (메모리 2배) | 높음 (배포 시 2배) |
| 환경 격리 | 프로세스 수준 | 컨테이너 수준 |
| 복잡도 | 낮음 | 중간 |
| 추천 사용처 | 단일 서버 | 컨테이너 환경, 빠른 롤백 필요 시 |

## 로깅

### 요청 로그 형식
서버는 다음 형식으로 요청 로그를 출력합니다:

```
[2025-10-14T08:27:46.991Z] 192.168.1.100 - GET / 200 - 5ms
```

- **타임스탬프**: ISO 8601 형식 (UTC)
- **클라이언트 IP**: Load Balancer 및 직접 연결 모두 자동 처리
  - Load Balancer 사용 시: X-Forwarded-For에서 실제 클라이언트 IP 추출
  - 직접 연결 시: socket.remoteAddress 사용
  - `trust proxy` 설정으로 안전하게 처리
- **HTTP 메서드 및 경로**
- **상태 코드**
- **응답 시간** (밀리초)

### 서버 시작 로그
```
Server is running on http://localhost:3000 ✅ [PID: 12345]
```
- PM2 cluster mode에서 각 인스턴스의 PID 확인 가능

## 에러 핸들링

### 비정상 종료 (exit 1)

- `uncaughtException`: 캐치되지 않은 예외
- `unhandledRejection`: 처리되지 않은 Promise rejection

### 정상 종료 (exit 0)

- `SIGINT`: Ctrl+C로 수동 종료
- `SIGTERM`: 시스템 종료 요청
- Graceful Shutdown: 10초 타임아웃 후 강제 종료

## 주요 스크립트

```json
{
  "start": "node --env-file=.env dist/server.js",
  "dev": "tsx watch --env-file=.env server.ts",
  "build": "tsc"
}
```

## Port 설정

기본 포트는 3000이며, `.env` 파일이나 환경변수로 변경 가능합니다:

```bash
PORT=3000
```

### Port 80 사용하기

Port 80을 사용하려면 Node.js에 권한을 부여해야 합니다:

```bash
# 1. Node.js에 포트 바인딩 권한 부여 (최초 1회만)
sudo setcap 'cap_net_bind_service=+ep' $(which node)

# 2. .env 파일 수정
echo "PORT=80" > .env

# 3. PM2 시작 (sudo 불필요)
pm2 start ecosystem.config.cjs

# 확인
pm2 logs
```

**참고:** (PORT=80 이용 필요시) Node.js에 포트 바인딩 권한 부여는 서버당 1회만 실행하면 됩니다.

## 배포 스크립트 가이드

### scripts/ (Ubuntu/Debian - apt 기반)
프로젝트 루트에서 실행하세요:

```bash
# Docker 설치
./scripts/install-docker.sh

# PM2 무중단 배포
./scripts/manual-deploy-pm2.sh

# Docker Compose 배포
./scripts/manual-deploy-docker.sh

# Git 코드 가져오기
./scripts/git-pull.sh
```

### scripts-dnf/ (Amazon Linux 2023 - dnf 기반)
프로젝트 루트에서 실행하세요:

```bash
# Docker 설치
./scripts-dnf/install-docker.sh

# PM2 무중단 배포
./scripts-dnf/manual-deploy-pm2.sh

# Docker Compose 배포
./scripts-dnf/manual-deploy-docker.sh

# Git 코드 가져오기
./scripts-dnf/git-pull.sh
```

**참고:**
- 모든 스크립트는 프로젝트 루트 기준으로 실행됩니다
- `.env` 파일은 `$HOME/express-app/.env` 경로에 위치해야 합니다
  - Ubuntu: `/home/ubuntu/express-app/.env`
  - Amazon Linux 2023: `/home/ec2-user/express-app/.env`
