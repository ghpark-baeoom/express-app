# CI/CD 파이프라인 가이드

GitHub Actions를 사용한 자동 배포 시스템 구축 가이드입니다.

## 목차
- [개요](#개요)
- [아키텍처](#아키텍처)
- [사전 준비](#사전-준비)
- [GitHub Secrets 설정](#github-secrets-설정)
- [배포 플로우](#배포-플로우)
- [사용 방법](#사용-방법)
- [트러블슈팅](#트러블슈팅)

## 개요

**배포 플로우:**
```
로컬 개발 → Git Push (main) → GitHub Actions 트리거
→ Docker 이미지 빌드 → ECR 푸시 → EC2 SSH 접속 → 배포
```

**장점:**
- ✅ 완전 자동화된 배포
- ✅ Docker를 통한 일관된 환경
- ✅ ECR로 이미지 버전 관리 및 롤백 가능
- ✅ 무중단 배포 (Blue-Green)
- ✅ 보안 (AWS ECR Private Registry)

## 아키텍처

```
┌─────────────┐     ┌──────────────────┐     ┌─────────┐     ┌─────────┐
│  로컬 개발   │ ──> │ GitHub Actions   │ ──> │   ECR   │ ──> │   EC2   │
│  (MacOS)    │     │  (CI/CD 빌드)    │     │ (이미지) │     │ (배포)  │
└─────────────┘     └──────────────────┘     └─────────┘     └─────────┘
```

## 사전 준비

### 1. AWS ECR 리포지토리 생성

```bash
# AWS CLI로 ECR 리포지토리 생성
aws ecr create-repository \
  --repository-name express-app \
  --region ap-northeast-2

# 출력 예시:
# {
#   "repository": {
#     "repositoryUri": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/express-app"
#   }
# }
```

또는 AWS 콘솔에서:
1. ECR 서비스 접속
2. "리포지토리 생성" 클릭
3. 이름: `express-app`
4. 리전: `ap-northeast-2`
5. 생성

### 2. IAM 사용자 생성 (GitHub Actions용)

**필요한 권한:**
- `AmazonEC2ContainerRegistryPowerUser` (ECR 푸시/풀)
- 또는 커스텀 정책:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
```

**IAM 사용자 생성 단계:**
1. AWS IAM → 사용자 → 사용자 추가
2. 이름: `github-actions-user`
3. 액세스 키 - 프로그래밍 방식 액세스
4. 권한: `AmazonEC2ContainerRegistryPowerUser`
5. 액세스 키 ID와 시크릿 키 저장 (GitHub Secrets에 사용)

### 3. EC2 보안 그룹 설정

Docker 사용 시 필요한 포트:
- **80**: HTTP (또는 원하는 포트)
- **22**: SSH (GitHub Actions 접속용)

### 4. EC2에 Docker 설치

```bash
# EC2 접속
ssh ubuntu@[EC2-IP]

# Docker 설치 스크립트 실행
cd ~/express-app
chmod +x install-docker.sh
./install-docker.sh

# Docker 확인
docker --version
docker compose version
```

## GitHub Secrets 설정

GitHub 저장소 → Settings → Secrets and variables → Actions → New repository secret

### 필수 Secrets

| Secret 이름 | 설명 | 예시 |
|------------|------|-----|
| `AWS_ACCESS_KEY_ID` | IAM 사용자 액세스 키 | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | IAM 사용자 시크릿 키 | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `AWS_REGION` | AWS 리전 | `ap-northeast-2` |
| `ECR_REPOSITORY` | ECR 리포지토리 이름 | `express-app` |
| `EC2_HOST` | EC2 Public IP | `43.201.64.12` |
| `EC2_USERNAME` | EC2 사용자명 | `ubuntu` |
| `EC2_SSH_KEY` | EC2 SSH Private Key | `-----BEGIN RSA PRIVATE KEY-----...` |

### EC2_SSH_KEY 생성 방법

**방법 1: 기존 키 사용**
```bash
# 로컬에서 기존 SSH 키 복사
cat ~/.ssh/your-ec2-key.pem
# 전체 내용을 복사하여 GitHub Secret에 추가
```

**방법 2: 새 키 생성**
```bash
# EC2에서 새 키 생성
ssh ubuntu@[EC2-IP]
mkdir -p ~/.ssh
cd ~/.ssh
ssh-keygen -t rsa -b 4096 -f github_actions_key -N ""

# 공개키를 authorized_keys에 추가
cat github_actions_key.pub >> authorized_keys
chmod 600 authorized_keys

# 개인키 출력 (GitHub Secret에 추가)
cat github_actions_key
```

## 배포 플로우

### 1. Git Push
```bash
git add .
git commit -m "Update feature"
git push origin main
```

### 2. GitHub Actions 자동 실행

**.github/workflows/deploy.yml**이 트리거되어 다음을 실행:

1. **Checkout 코드**
2. **AWS 인증**
3. **ECR 로그인**
4. **Docker 이미지 빌드**
   ```bash
   docker build -t express-app .
   ```
5. **ECR에 이미지 푸시**
   ```bash
   docker tag express-app:latest [ECR_URI]:latest
   docker push [ECR_URI]:latest
   ```
6. **EC2 SSH 접속 및 배포**
   - ECR에서 이미지 pull
   - docker-compose로 재시작

### 3. EC2에서 자동 배포

`scripts/deploy-docker.sh`가 실행되어:
1. AWS ECR 로그인
2. 최신 이미지 pull
3. 기존 컨테이너 중지
4. 새 컨테이너 시작
5. 헬스체크

## 사용 방법

### 배포하기

```bash
# 로컬에서 코드 수정 후
git add .
git commit -m "Fix bug"
git push origin main

# GitHub Actions에서 자동 배포 시작
# 진행 상황: GitHub → Actions 탭에서 확인
```

### 배포 상태 확인

```bash
# GitHub Actions 로그 확인
# Repository → Actions → 최신 워크플로우 클릭

# EC2에서 직접 확인
ssh ubuntu@[EC2-IP]
docker ps
docker logs express-app
```

### 롤백하기

```bash
# 방법 1: Git revert
git revert HEAD
git push origin main

# 방법 2: 이전 이미지로 수동 배포
ssh ubuntu@[EC2-IP]
docker pull [ECR_URI]:[TAG]
docker compose down
docker compose up -d
```

## 트러블슈팅

### 1. ECR 로그인 실패

**에러:**
```
Error: Cannot perform an interactive login from a non TTY device
```

**해결:**
```yaml
# deploy.yml에서 확인
- name: Login to Amazon ECR
  run: |
    aws ecr get-login-password --region ${{ secrets.AWS_REGION }} | \
    docker login --username AWS --password-stdin ${{ secrets.ECR_REGISTRY }}
```

### 2. SSH 접속 실패

**에러:**
```
Permission denied (publickey)
```

**해결:**
1. EC2_SSH_KEY가 올바른지 확인
2. EC2 ~/.ssh/authorized_keys에 공개키 추가 확인
3. SSH 키 형식 확인 (BEGIN/END 포함)

### 3. Docker 이미지 pull 실패

**에러:**
```
pull access denied, repository does not exist
```

**해결:**
```bash
# EC2에서 ECR 로그인 확인
aws ecr get-login-password --region ap-northeast-2 | \
docker login --username AWS --password-stdin [ECR_URI]

# IAM 권한 확인
aws ecr describe-repositories
```

### 4. 포트 충돌

**에러:**
```
Bind for 0.0.0.0:80 failed: port is already allocated
```

**해결:**
```bash
# 기존 컨테이너 확인 및 중지
docker ps -a
docker stop express-app
docker rm express-app

# 또는 PM2와 충돌 시
pm2 delete all
```

## 환경별 배포

### Development (dev 브랜치)

```yaml
# .github/workflows/deploy-dev.yml
on:
  push:
    branches: [ dev ]

env:
  IMAGE_TAG: dev
  EC2_HOST: ${{ secrets.EC2_DEV_HOST }}
```

### Production (main 브랜치)

```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches: [ main ]

env:
  IMAGE_TAG: latest
  EC2_HOST: ${{ secrets.EC2_HOST }}
```

## 보안 고려사항

1. **GitHub Secrets 사용**: 절대 코드에 하드코딩 금지
2. **IAM 최소 권한 원칙**: ECR 접근만 허용
3. **SSH 키 관리**: 정기적으로 키 로테이션
4. **ECR Private Registry**: Public 노출 방지
5. **.env 파일 보안**: GitHub에 커밋하지 않음 (.gitignore)

## 비용 최적화

- **ECR**: 이미지 lifecycle 정책 설정 (오래된 이미지 자동 삭제)
```bash
# 최근 5개 이미지만 유지
aws ecr put-lifecycle-policy --repository-name express-app --lifecycle-policy-text '{
  "rules": [{
    "rulePriority": 1,
    "selection": {
      "tagStatus": "any",
      "countType": "imageCountMoreThan",
      "countNumber": 5
    },
    "action": { "type": "expire" }
  }]
}'
```

## 참고 자료

- [GitHub Actions 문서](https://docs.github.com/actions)
- [AWS ECR 문서](https://docs.aws.amazon.com/ecr/)
- [Docker Compose 문서](https://docs.docker.com/compose/)
- [PM2 vs Docker 비교](../README.md#pm2-vs-docker-compose)

## 다음 단계

- [ ] Blue-Green 배포 전략 적용
- [ ] 모니터링 추가 (CloudWatch, Datadog)
- [ ] 자동 롤백 설정
- [ ] Slack/Discord 알림 추가
- [ ] 로드 테스트 자동화
