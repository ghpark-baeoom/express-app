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
├── dist/                    # 빌드된 JavaScript 파일
├── server.ts               # 메인 서버 파일
├── ecosystem.config.mjs    # PM2 설정 파일
├── deploy.sh              # 무중단 배포 스크립트
├── .env                   # 환경 변수
├── tsconfig.json          # TypeScript 설정
├── package.json           # 프로젝트 의존성
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

# 2. 의존성 설치 (빌드를 위해 devDependencies 포함)
npm ci

# 3. TypeScript 빌드
npm run build

# 4. PM2로 앱 실행
pm2 start ecosystem.config.cjs

# 5. 로그 확인 (정상 작동 확인)
pm2 logs

# 6. 현재 프로세스 목록 저장
pm2 save

# 7. 서버 재부팅 시 자동 시작 설정
pm2 startup
# 위 명령어 실행 후 출력되는 명령어를 복사하여 실행 (sudo 권한 필요)
```

### 2. 무중단 재배포

코드 변경 후 무중단으로 배포하려면:

```bash
# 배포 스크립트 실행
./deploy.sh
```

또는 수동으로:

```bash
# 1. 최신 코드 받기
git pull origin main

# 2. 의존성 설치
npm ci --omit=dev

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

PM2 클러스터 모드를 사용하여 무중단 배포를 구현합니다:

1. **2개 이상의 인스턴스 실행** (`instances: 2`)
2. **`pm2 reload` 사용 시:**
   - Instance 1 종료 → 빌드 → 재시작 (Instance 2가 요청 처리)
   - Instance 2 종료 → 빌드 → 재시작 (Instance 1이 요청 처리)
   - **다운타임 0초!**

**주의:**

- `pm2 restart`: 모든 인스턴스 동시 재시작 → 다운타임 발생
- `pm2 reload`: 하나씩 순차 재시작 → 무중단 ⭐

## Docker 배포

### 빌드 및 실행

```bash
# Docker 이미지 빌드
docker build -t express-app .

# 컨테이너 실행
docker run -p 3000:3000 --env-file .env express-app

# 또는 환경변수 직접 지정
docker run -p 8080:8080 -e PORT=8080 express-app
```

### Docker Compose 사용

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

## 로깅

서버는 다음 형식으로 요청 로그를 출력합니다:

```
[2025-10-14T08:27:46.991Z] 192.168.1.100 - GET / 200 - 5ms
```

- **타임스탬프**: ISO 8601 형식 (UTC)
- **클라이언트 IP**: X-Forwarded-For 헤더 우선, 없으면 req.ip
- **HTTP 메서드 및 경로**
- **상태 코드**
- **응답 시간** (밀리초)

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
PORT=80
```

**참고:** Port 80 사용 시 root 권한 필요:

```bash
sudo PORT=80 pm2 start ecosystem.config.mjs
```

## 라이선스

ISC
