# Blue-Green 무중단 배포 가이드

## 개요

이 프로젝트는 **Blue-Green 배포 전략**을 사용하여 Docker 환경에서 무중단 배포를 구현합니다.

## Blue-Green 배포란?

두 개의 동일한 프로덕션 환경(Blue와 Green)을 유지하면서, 새 버전을 배포할 때 트래픽을 순간적으로 전환하는 방식입니다.

```
사용자 → Nginx (포트 3001)
         ├─→ Blue 환경 (포트 3002)  ← 현재 활성
         └─→ Green 환경 (포트 3003) ← 대기 중
```

## 아키텍처

### 컨테이너 구조

| 컨테이너 | 포트 | 역할 |
|---------|------|------|
| `hono-nginx` | 3001 | 리버스 프록시 (외부 접근) |
| `hono-app-blue` | 3002 | Blue 환경 (앱 인스턴스) |
| `hono-app-green` | 3003 | Green 환경 (앱 인스턴스) |

### Nginx 동작 원리

```nginx
# nginx/conf.d/active.conf 파일이 현재 활성 환경을 결정
server hono-app-blue:3001;   # Blue 활성화
# 또는
server hono-app-green:3001;  # Green 활성화
```

Nginx는 `active.conf` 파일을 읽어서 트래픽을 Blue 또는 Green으로 전달합니다.

## 배포 프로세스

### 1단계: 초기 상태

```
사용자 → Nginx → Blue (v1.0) ✅ 트래픽 100%
                 Green (대기)
```

### 2단계: 새 버전 배포

```bash
./scripts/manual-deploy-docker-rolling.sh
```

**실행 과정**:

1. **환경 감지**: 현재 Blue가 활성화되어 있음을 확인
2. **코드 가져오기**: `git pull origin main`
3. **빌드**: Green 환경에 새 버전(v2.0) 이미지 빌드
4. **시작**: Green 컨테이너 시작 (포트 3002)

```
사용자 → Nginx → Blue (v1.0) ✅ 트래픽 100%
                 Green (v2.0) 🔨 배포 중...
```

### 3단계: Health Check

Green 환경이 정상적으로 동작하는지 확인:

```bash
# 10회 시도, 2초 간격
curl http://localhost:3002/health
```

```
사용자 → Nginx → Blue (v1.0) ✅ 트래픽 100%
                 Green (v2.0) ✅ 준비 완료
```

### 4단계: 트래픽 전환

Nginx 설정을 변경하여 트래픽을 Green으로 전환:

```bash
# active.conf를 green.conf로 교체
cp nginx/conf.d/green.conf nginx/conf.d/active.conf
docker compose exec nginx nginx -s reload
```

```
사용자 → Nginx → Blue (v1.0) (대기)
                 Green (v2.0) ✅ 트래픽 100%
```

**무중단 배포 완료!** 사용자는 서비스 중단을 느끼지 못합니다.

### 5단계: 기존 환경 정리

Green이 안정적으로 동작하면 Blue 중지:

```bash
docker compose stop hono-app-blue
```

```
사용자 → Nginx → Blue (중지됨)
                 Green (v2.0) ✅ 트래픽 100%
```

### 6단계: 다음 배포

다음 배포 시에는 반대로 진행:

```
사용자 → Nginx → Blue (v3.0) ✅ 트래픽 100%  ← 새 버전
                 Green (v2.0) (중지됨)
```

## 사용 방법

### 초기 설정

```bash
# 1. Blue 환경과 Nginx 시작
docker compose up -d

# 2. 접속 확인
curl http://localhost:3000/health
```

### 롤링 배포 실행

**Ubuntu/Debian**:
```bash
cd ~/hono-app
./scripts/manual-deploy-docker-rolling.sh
```

**Amazon Linux 2023**:
```bash
cd ~/hono-app
./scripts-dnf/manual-deploy-docker-rolling.sh
```

### 배포 로그 예시

```
🚀 Starting Hono app Blue-Green Rolling Deployment...
📊 Current active environment: blue (port 3001)
🎯 Deploying to: green (port 3002)

📥 Pulling latest code from git...
🔨 Building new Hono app image for green environment...
🚀 Starting green environment (port 3002)...

⏳ Waiting for green environment to be healthy...
Attempt 1/10 - waiting...
Attempt 2/10 - waiting...
✅ green environment is healthy!

🔄 Switching Nginx traffic from blue to green...
✅ Nginx successfully switched to green environment

⏳ Waiting 3 seconds to ensure traffic is stable...
🛑 Stopping blue environment (port 3001)...

✅ Blue-Green rolling deployment completed successfully!
🎉 Active environment: green (port 3002)
💡 Access your app at: http://localhost:3000
```

## 장점

### 1. 무중단 배포
- 사용자는 서비스 중단을 전혀 느끼지 못함
- 다운타임 0초

### 2. 빠른 롤백
문제 발생 시 즉시 이전 버전으로 복구:

```bash
# active.conf를 다시 이전 환경으로 변경
cp nginx/conf.d/blue.conf nginx/conf.d/active.conf
docker compose exec nginx nginx -s reload

# 이전 환경 재시작
docker compose start hono-app-blue
```

몇 초 안에 롤백 완료!

### 3. 안전한 검증
- 새 버전이 완전히 준비되고 검증된 후에만 트래픽 전환
- Health check 실패 시 자동 롤백

### 4. A/B 테스트 가능
필요하다면 두 버전을 동시에 실행하고 트래픽을 분산할 수도 있습니다.

## 자동 롤백

Health check 실패 시 스크립트가 자동으로 롤백:

```bash
❌ green environment failed health check after 10 attempts!
Rolling back: stopping green environment...
📊 Current status:
  hono-nginx        running
  hono-app-blue     running  ← 기존 환경 유지
  hono-app-green    exited
```

기존 환경이 계속 서비스를 제공하므로 안전합니다.

## 파일 구조

```
hono-app/
├── docker-compose.yml              # Blue/Green/Nginx 정의
├── nginx/
│   ├── nginx.conf                  # Nginx 메인 설정
│   └── conf.d/
│       ├── blue.conf              # Blue 백엔드 정의
│       ├── green.conf             # Green 백엔드 정의
│       └── active.conf            # 현재 활성 환경 (동적 변경)
├── scripts/
│   ├── manual-deploy-docker.sh              # 일반 배포 (다운타임 있음)
│   └── manual-deploy-docker-rolling.sh      # Blue-Green 무중단 배포
└── scripts-dnf/
    ├── manual-deploy-docker.sh              # 일반 배포 (Amazon Linux)
    └── manual-deploy-docker-rolling.sh      # Blue-Green 무중단 배포 (Amazon Linux)
```

## 주의사항

### 1. 리소스 사용
- 배포 중에는 두 컨테이너가 동시에 실행됨
- 메모리와 CPU 리소스가 평소의 2배 필요

### 2. 데이터베이스 마이그레이션
데이터베이스 스키마를 변경하는 배포는 주의:
- 새 버전과 구 버전이 동시에 DB를 사용
- 호환성을 유지해야 함 (Backward Compatible Migration)

### 3. 세션 관리
- Stateful 애플리케이션은 세션 공유 필요
- Redis 등 외부 세션 저장소 사용 권장

### 4. 외부 포트 변경
- 기존: 3001 (직접 접근)
- 변경 후: 3000 (Nginx를 통한 접근)

방화벽/보안그룹 설정을 3000 포트로 변경해야 합니다.

## PM2 배포와 비교

| 항목 | PM2 방식 | Docker Blue-Green |
|------|----------|-------------------|
| 무중단 배포 | ✅ 가능 | ✅ 가능 |
| 다운타임 | 0초 | 0초 |
| 리소스 사용 | 적음 (프로세스) | 많음 (2개 컨테이너) |
| 롤백 속도 | 빠름 (프로세스 재시작) | 매우 빠름 (트래픽 전환) |
| 컨테이너화 | ❌ | ✅ |
| 복잡도 | 낮음 | 중간 |

**추천**:
- **단일 서버 + 리소스 제약**: PM2 방식 (`manual-deploy-pm2.sh`)
- **컨테이너 환경 + 무중단 필요**: Blue-Green 방식 (`manual-deploy-docker-rolling.sh`)

## 문제 해결

### Nginx 설정 확인
```bash
docker compose exec nginx cat /etc/nginx/conf.d/active.conf
```

### 현재 활성 환경 확인
```bash
cat nginx/conf.d/active.conf
```

### 컨테이너 상태 확인
```bash
docker compose ps
```

### 로그 확인
```bash
# Blue 환경 로그
docker compose logs hono-app-blue

# Green 환경 로그
docker compose logs hono-app-green

# Nginx 로그
docker compose logs nginx
```

### 수동 트래픽 전환
```bash
# Green으로 전환
cp nginx/conf.d/green.conf nginx/conf.d/active.conf
docker compose exec nginx nginx -s reload

# Blue로 전환
cp nginx/conf.d/blue.conf nginx/conf.d/active.conf
docker compose exec nginx nginx -s reload
```

## 추가 개선 사항

### 1. 헬스체크 강화
```bash
# /health 엔드포인트에 더 많은 검증 추가
# - DB 연결 확인
# - 외부 API 연결 확인
# - 메모리 사용량 확인
```

### 2. 모니터링 추가
- Prometheus + Grafana로 각 환경 모니터링
- Blue/Green 트래픽 비율 시각화

### 3. 자동화
- GitHub Actions + Webhook으로 자동 배포
- Slack/Discord 알림 통합

## 참고 문서

- [README.md](./README.md) - 프로젝트 전체 개요
- [README_BUN_REUSEPORT.md](./README_BUN_REUSEPORT.md) - PM2 배포 가이드
- [README_MULTI_PLATFORM.md](./README_MULTI_PLATFORM.md) - Docker 멀티 플랫폼 빌드
