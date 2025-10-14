import express from "express";

const app = express();

// Trust proxy for accurate IP addresses
app.set("trust proxy", true);

// Request logging middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    const duration = Date.now() - start;
    const timestamp = new Date().toISOString();
    // Get original client IP from X-Forwarded-For or fallback to req.ip
    const forwardedFor = req.headers["x-forwarded-for"];
    const clientIp = forwardedFor
      ? Array.isArray(forwardedFor)
        ? forwardedFor[0]
        : forwardedFor.split(",")[0].trim()
      : req.ip || req.socket.remoteAddress;
    console.log(
      `[${timestamp}] ${clientIp} - ${req.method} ${req.path} ${res.statusCode} - ${duration}ms`
    );
  });
  next();
});

app.get("/", (_req, res) => {
  res.send("안녕!");
});

app.get("/health", (_req, res) => {
  res.status(200).send("OK");
});

const PORT = process.env.PORT || 3000;

const server = app.listen(PORT, () => {
  console.log(`.env $PORT: ${PORT}`);
  console.log(`Server is running on http://localhost:${PORT} ✅`);
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
