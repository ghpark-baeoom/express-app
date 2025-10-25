import express from "express";

const app = express();

// Trust proxy for accurate IP addresses
// app.set("trust proxy", true) 로 설정하면 Express는 **“모든 프록시를 신뢰”**하게 됩니다.
// 즉, 숫자(1, 2, 3...)처럼 hop 개수를 지정하는 대신,
// 들어온 X-Forwarded-For 체인 전체를 신뢰하고, 맨 왼쪽(첫 번째) IP를 원본 클라이언트 IP로 간주합니다.
app.set("trust proxy", 1); // 수정 필요!

/**
 * ✅ URL 끝의 슬래시("/")를 제거하는 Express 미들웨어 (루트 "/"는 예외)
 *
 * @description
 * - 표준 URL API를 사용하여 URL 전체를 안전하게 파싱합니다.
 * - 쿼리스트링(`?a=1&b=2`)은 그대로 유지합니다.
 * - 인코딩된 문자(`%20`, `%2F` 등)나 다중 슬래시(`///`)도 정상적으로 처리합니다.
 * - Nginx 등 리버스 프록시 뒤에서도 원본 요청 경로(`req.originalUrl`)를 기준으로 작동합니다.
 * - URL 파싱 오류 발생 시, 다음 미들웨어로 안전하게 제어를 넘깁니다.
 *
 * @example
 * // before:  https://example.com/hello/?a=1
 * // after:   https://example.com/hello?a=1
 *
 * @param {import("express").Request} req - Express 요청 객체
 * @param {import("express").Response} res - Express 응답 객체
 * @param {import("express").NextFunction} next - 다음 미들웨어로 제어를 넘기는 함수
 */
app.use((req, res, next) => {
  if (req.path !== "/" && req.path.endsWith("/")) {
    try {
      // 표준 URL API를 사용해 원본 URL 전체(경로 + 쿼리)를 파싱
      const base = `http://${req.headers.host || "localhost"}`;
      const url = new URL(req.originalUrl, base);

      // 경로 끝부분의 중복 슬래시들을 모두 제거
      url.pathname = url.pathname.replace(/\/+$/, "");

      // 쿼리스트링을 유지한 채로 301 리다이렉트 수행
      res.redirect(301, url.pathname + url.search);
    } catch (err) {
      console.error("URL 파싱 중 오류 발생:", err);
      next(); // 오류 발생 시 다음 미들웨어로 제어 이동
    }
  } else {
    next();
  }
});

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    const duration = Date.now() - start;
    const timestamp = new Date().toISOString();

    // Get client IP: req.ip handles both LB and direct connection cases
    // When behind LB with trust proxy: req.ip extracts from X-Forwarded-For
    // When direct connection: req.ip returns socket.remoteAddress
    let clientIp = req.ip || req.socket.remoteAddress || "unknown";

    // Convert IPv6 to IPv4 if applicable
    if (clientIp) {
      // Remove IPv6 prefix (::ffff:) for IPv4-mapped addresses
      clientIp = clientIp.replace(/^::ffff:/, "");
      // Convert ::1 (IPv6 localhost) to 127.0.0.1 (IPv4 localhost)
      if (clientIp === "::1") {
        clientIp = "127.0.0.1";
      }
    }

    console.log(
      `[${timestamp}] ${clientIp} - ${req.method} ${req.path} ${res.statusCode} - ${duration}ms`
    );
  });
  next();
});

app.get("/", (_req, res) => {
  res.send("💗 HELLO EXPRESS!\n");
});

app.get("/hello", (_req, res) => {
  res.status(200).json({ message: "💗 HELLO EXPRESS FROM JSON!" });
});

app.get("/health", (_req, res) => {
  res.status(200).send("💗 EXPRESS: HEALTH CHECK SUCCESS\n");
});

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`.env $PORT: ${PORT}`);
  console.log(
    `Server is running on http://localhost:${PORT} ✅ [PID: ${process.pid}]`
  );

  // PM2 ready signal (cluster mode)
  if (process.send) {
    process.send("ready");
  }
});

// Error Handlers (비정상 종료)
process.on("uncaughtException", (error) => {
  console.error("Uncaught Exception:", error);
  process.exit(1);
});

process.on("unhandledRejection", (reason, promise) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
  process.exit(1);
});

// Graceful Shutdowns (정상 종료)
const gracefulShutdown = () => {
  console.log("Server is shutting down gracefully...");
  server.close(() => {
    console.log("Server closed");
    process.exit(0);
  });

  // 강제 종료 타임아웃 (10초)
  setTimeout(() => {
    console.error("Forced shutdown after timeout");
    process.exit(1);
  }, 10000);
};

process.on("SIGINT", gracefulShutdown);
process.on("SIGTERM", gracefulShutdown);
process.on("message", (msg: any) => {
  if (msg === "shutdown") {
    gracefulShutdown();
  }
});
