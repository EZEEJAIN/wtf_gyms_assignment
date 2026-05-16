const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const { attachUser } = require("./middlewares/auth");
const {
  requestIdMiddleware,
  requestLogger,
  apiRateLimiter,
  notFoundHandler,
  errorHandler,
} = require("./middlewares/http");
const { jsonBodyLimit, corsAllowedOrigins } = require("./config/env");
const healthRoutes = require("./routes/health");
const authRoutes = require("./routes/auth");
const adminRoutes = require("./routes/admin");

const app = express();

app.use(requestIdMiddleware);
app.use(requestLogger());

app.use(cors()); 
app.use(express.json({ limit: jsonBodyLimit }));

app.use(
  helmet({
    crossOriginResourcePolicy: { policy: "cross-origin" },
  })
);
app.use(attachUser);

app.use("/api", apiRateLimiter);

app.get("/", (_req, res) => {
  res.json({ message: "WTF GYMS is running" });
});

app.use("/health", healthRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/admin", adminRoutes);

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
