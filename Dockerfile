# Build stage
FROM node:22-alpine AS builder

WORKDIR /app

# 1) 패키지 메타만 먼저 복사 (캐시 최대화)
COPY package*.json ./
# (필요 시) COPY .npmrc ./

# 2) CI 설치 (dev 포함)
RUN npm ci

# 3) 소스 복사 & 빌드
COPY . .
RUN npm run build

# Production stage
FROM node:22-alpine AS production

WORKDIR /app
ENV NODE_ENV=production

# 1) 패키지 메타 복사 후 prod 의존성만 설치
COPY --chown=nodejs:nodejs package*.json ./
# (필요 시) COPY --chown=nodejs:nodejs .npmrc ./
RUN npm ci --omit=dev \
 && npm cache clean --force

# 2) 빌드 산출물만 복사 (필요 파일 추가 복사)
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
# 예: COPY --from=builder --chown=nodejs:nodejs /app/public ./public

# 3) 비루트 사용자/그룹 생성 (UID/GID = 1001 고정)
RUN addgroup -g 1001 -S nodejs \
 && adduser -u 1001 -S -G nodejs nodejs

# (COPY에서 이미 chown 했으므로 별도 chown 레이어 불필요)
USER nodejs

EXPOSE 3000

# Health check (200 OK 기대) - error 핸들러 추가
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:${PORT:-3000}/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

# Start application
CMD ["node", "dist/server.js"]
