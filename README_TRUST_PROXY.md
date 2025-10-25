# Express Trust Proxy 설정 가이드

## 요약

trust proxy: false → Express는 X-Forwarded-For를 무시합니다.
→ req.ip = socket.remoteAddress (앱에 직접 연결한 피어의 IP; 보통 Nginx나 ALB의 IP)

trust proxy: true → Express는 ‘직접 연결한 한 단계(=socket.remoteAddress)’를 신뢰합니다.
→ 동작: XFF 오른쪽에 socket.remoteAddress와 같은 항목이 있으면 그 항목(한 홉)을 제거하고, 그 왼쪽(=오른쪽에서 첫 비신뢰)을 req.ip로 삼습니다.
→ 따라서 단일 신뢰 프록시(예: ALB → Nginx → 앱 같은 일반적 토폴로지) 에서는 보통 XFF의 맨 왼쪽(원본 클라이언트 IP) 가 req.ip가 됩니다.
→ 하지만 프록시 체인에 비신뢰 공용 프록시가 끼어있으면 그 지점에서 멈춰서 원본까지 도달하지 못할 수 있습니다.

trust proxy에 IP/CIDR 리스트를 주는 경우 → Express는 오른쪽부터 그 CIDR/목록에 해당하는 항목들을 모두 제거하고, 남는 오른쪽에서 첫 비신뢰 IP를 req.ip로 결정합니다.
→ 예: ['127.0.0.1','10.0.0.0/8']이면 오른쪽에서 127.0.0.1·10.x.x.x들을 모두 제거한 뒤 남는 값.

## 예시로 확인

X-Forwarded-For: 203.0.113.45, 198.51.100.10, 10.0.1.12, 127.0.0.1
(왼쪽=원본, 오른쪽=앱에 가까운 홉)

trust proxy: false
→ req.ip = 127.0.0.1 (socket.remoteAddress)

trust proxy: true and socket.remoteAddress === 127.0.0.1
→ 오른쪽에서 127.0.0.1 제거 → 다음 오른쪽 값 10.0.1.12는 비신뢰(Express는 한 홉만 신뢰) 이므로 멈춤 → req.ip = 10.0.1.12
(만약 10.0.1.12가 직접 연결한 프록시라면 그 경우엔 더 왼쪽 값이 선택될 수 있음)

trust proxy: ['127.0.0.1','10.0.0.0/8']
→ 오른쪽에서 127.0.0.1 제거, 10.0.1.12 제거 → 남는 오른쪽 첫 비신뢰는 198.51.100.10 → req.ip = 198.51.100.10

trust proxy: '0.0.0.0/0' (전부 신뢰)
→ XFF의 모든 항목 제거 → 남는 값 없음 → fallback으로 socket.remoteAddress 사용 → req.ip = socket.remoteAddress
(이건 보안상 위험합니다 — XFF 스푸핑에 취약)

## 결론

trust proxy: false = XFF 무시 → req.ip = 직접 연결한 소켓 IP

trust proxy: true = 직접 연결한 한 단계만 신뢰 → 보통은 XFF에서 한 항목 제거한 뒤의 값(대부분 정상 구성에서는 원본 IP가 됨)

가장 안전하고 예측 가능한 방법은 trust proxy에 명시적 IP/CIDR 리스트를 넣어 Express가 어떤 항목을 신뢰할지 정확히 알게 하는 것(예: ALB·Nginx가 사용하는 사설 CIDR 또는 호스트 IP).

Nginx의 set_real_ip_from 설정과 Express의 trust proxy를 일치시키면 결과가 일관됩니다.

## 개요

Express의 `trust proxy` 설정은 **X-Forwarded-For 헤더를 통해 클라이언트의 실제 IP 주소를 정확하게 파악**하기 위한 매우 중요한 설정입니다.

프록시(Nginx, ALB, Cloudflare 등)를 거친 요청에서 `req.ip`가 프록시의 IP가 아닌 **실제 사용자 IP**를 가리키도록 하려면 이 설정을 올바르게 구성해야 합니다.

---

## X-Forwarded-For 헤더 구조

프록시를 거친 요청의 `X-Forwarded-For` 헤더는 다음과 같은 형식입니다:

```
X-Forwarded-For: 203.0.113.45, 172.31.10.25, 10.0.1.12, 127.0.0.1
```

### 각 IP의 의미

| 위치                   | IP             | 설명                                            |
| ---------------------- | -------------- | ----------------------------------------------- |
| **맨 왼쪽 (첫 번째)**  | `203.0.113.45` | **실제 브라우저 사용자의 IP** (원본 클라이언트) |
| 중간                   | `172.31.10.25` | **중간 프록시 #1** (예: ALB, Cloudflare Tunnel) |
| 중간                   | `10.0.1.12`    | **중간 프록시 #2** (예: 내부 로드밸런서)        |
| **맨 오른쪽 (마지막)** | `127.0.0.1`    | **Express 직전 프록시** (예: Nginx)             |

---

## Trust Proxy 작동 원리

Express는 `app.set('trust proxy', N)` 설정에 따라:

1. **오른쪽부터 N개의 IP를 제거** (신뢰 가능한 프록시로 간주)
2. **남아 있는 IP 중 가장 오른쪽 것을 `req.ip`로 지정**

### 예시

#### 시나리오: 프록시 체인

```
X-Forwarded-For: 203.0.113.45, 172.31.10.25, 10.0.1.12, 127.0.0.1
```

#### 각 설정에 따른 결과

```
N=0 (아무 프록시도 신뢰 안 함)
→ req.ip = 127.0.0.1  ❌ (프록시 IP)

N=1 (Nginx 신뢰)
→ 제거: 127.0.0.1
→ req.ip = 10.0.1.12  ❌ (여전히 프록시 IP)

N=2 (Nginx + ALB 신뢰)
→ 제거: 127.0.0.1, 10.0.1.12
→ req.ip = 172.31.10.25  ❌ (여전히 중간 프록시 IP)

N=3 (Nginx + ALB + Cloudflare 신뢰)
→ 제거: 127.0.0.1, 10.0.1.12, 172.31.10.25
→ req.ip = 203.0.113.45  ✅ (실제 사용자 IP)
```

---

## 상황별 설정 가이드

### 1️⃣ 프록시 없음 (로컬 개발 환경)

```javascript
app.set("trust proxy", false);
```

**언제**: 개발 환경에서 Nginx나 로드밸런서 없이 직접 Express 서버에 접속
**결과**: `req.ip` = 직접 연결 클라이언트의 IP

---

### 2️⃣ Nginx만 있는 경우

```javascript
app.set("trust proxy", 1);
```

**구조**:

```
Client (203.0.113.45)
    ↓
Nginx (127.0.0.1)
    ↓
Express
```

**X-Forwarded-For**: `203.0.113.45, 127.0.0.1`
**결과**: `req.ip = 203.0.113.45` ✅

---

### 3️⃣ Nginx + ALB 조합

```javascript
app.set("trust proxy", 2);
```

**구조**:

```
Client (203.0.113.45)
    ↓
ALB (172.31.10.25)
    ↓
Nginx (127.0.0.1)
    ↓
Express
```

**X-Forwarded-For**: `203.0.113.45, 172.31.10.25, 127.0.0.1`
**결과**: `req.ip = 203.0.113.45` ✅

---

### 4️⃣ Nginx + ALB + Cloudflare 조합

```javascript
app.set("trust proxy", 3);
```

**구조**:

```
Client (203.0.113.45)
    ↓
Cloudflare (10.0.1.12)
    ↓
ALB (172.31.10.25)
    ↓
Nginx (127.0.0.1)
    ↓
Express
```

**X-Forwarded-For**: `203.0.113.45, 10.0.1.12, 172.31.10.25, 127.0.0.1`
**결과**: `req.ip = 203.0.113.45` ✅

---

## IP CIDR 기반 설정 (권장)

`trust proxy`를 **숫자 대신 IP CIDR 범위 배열**로 설정하면, 더욱 **안전하고 유연한 구성**이 가능합니다.

### 설정 예시

```javascript
app.set("trust proxy", [
  "loopback", // 127.0.0.1, ::1 (로컬호스트)
  "10.0.0.0/8", // AWS VPC CIDR (ALB, EC2 포함)
  "172.16.0.0/12", // 사설망 (Cloudflare Tunnel, Wireguard 등)
  "192.168.0.0/16", // 로컬 네트워크 (홈 네트워크 등)
  "103.21.244.0/22", // Cloudflare IP 범위 (예시)
]);
```

### 각 CIDR 범위의 의미

| CIDR             | 범위                          | 포함되는 IP            | 사용 사례                             |
| ---------------- | ----------------------------- | ---------------------- | ------------------------------------- |
| `loopback`       | 127.0.0.1, ::1                | 로컬호스트             | 로컬 개발, 동일 머신의 프록시         |
| `10.0.0.0/8`     | 10.0.0.0 ~ 10.255.255.255     | AWS VPC, EC2 내부 통신 | AWS ALB, NLB                          |
| `172.16.0.0/12`  | 172.16.0.0 ~ 172.31.255.255   | 사설 네트워크          | Docker, Kubernetes, Cloudflare Tunnel |
| `192.168.0.0/16` | 192.168.0.0 ~ 192.168.255.255 | 로컬 네트워크          | 홈/회사 네트워크, 내부 인트라넷       |

---

## AWS 기반 배포 시 설정

### 📌 ALB (Application Load Balancer)

ALB는 EC2 인스턴스에 요청을 전달할 때 `X-Forwarded-For` 헤더를 자동으로 추가합니다.

```javascript
// ALB만 있는 경우
app.set("trust proxy", 1);

// ALB + Nginx 구성
app.set("trust proxy", 2);

// IP CIDR 기반 (권장)
app.set("trust proxy", ["loopback", "10.0.0.0/8"]);
```

### 📌 VPC와 보안

AWS VPC 내 통신은 `10.0.0.0/8` CIDR를 사용하므로, 이 범위의 프록시를 신뢰하는 것이 안전합니다.

```javascript
// VPC 내부 프록시만 신뢰 (외부 IP는 거부)
app.set("trust proxy", "10.0.0.0/8");
```

---

## ⚠️ 주의사항

### 1. 숫자(`N`)로 설정할 때의 위험성

```javascript
// ❌ 위험: 너무 높은 숫자
app.set("trust proxy", 10);
```

프록시 체인이 실제로 10개가 아니면, 안신뢰할 수 없는 프록시의 IP를 사용자 IP로 간주할 수 있습니다.

### 2. `true` 로 설정하면 절대 금지 ⛔

```javascript
// ❌ 절대 하면 안 됨!
app.set("trust proxy", true);
```

이렇게 설정하면:

- Express가 **모든 프록시(0.0.0.0/0)를 신뢰**
- X-Forwarded-For 헤더를 완전히 신뢰
- 공격자가 임의로 IP를 조작할 수 있음
- 인증, 비율 제한, 로깅 등이 무효화됨

### 3. 헤더 조작 공격 방지

프록시가 신뢰할 수 없으면 X-Forwarded-For를 검증하고, 필요시 별도의 인증 방식을 사용해야 합니다.

---

## 설정 확인 방법

### 1. 현재 설정 확인

```javascript
console.log(app.get("trust proxy"));
```

### 2. 요청에서 IP 확인

```javascript
app.get("/check-ip", (req, res) => {
  console.log("req.ip:", req.ip);
  console.log("X-Forwarded-For:", req.get("X-Forwarded-For"));
  res.json({
    ip: req.ip,
    xForwardedFor: req.get("X-Forwarded-For"),
  });
});
```

### 3. Nginx 테스트

```bash
curl -H "X-Forwarded-For: 203.0.113.45" http://localhost:3000/check-ip
```

---

## 배포 체크리스트

- [ ] 프록시 체인 구조를 정확히 파악했는가?
- [ ] 프록시의 개수를 정확히 세었는가?
- [ ] 각 프록시 서버의 IP 범위를 확인했는가?
- [ ] `trust proxy` 설정이 환경별로 다른가? (개발 vs 운영)
- [ ] IP CIDR 기반 설정으로 더 안전하게 구성했는가?
- [ ] 테스트를 통해 `req.ip`가 정확한지 확인했는가?
- [ ] 로깅에 올바른 IP가 기록되는지 확인했는가?

---

## 참고 자료

- [Express Trust Proxy 공식 문서](https://expressjs.com/en/guide/behind-proxies.html)
- [X-Forwarded-For 헤더 명세](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-For)
- [IP CIDR 범위 참조](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing)
