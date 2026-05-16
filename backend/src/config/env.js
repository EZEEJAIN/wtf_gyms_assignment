const dotenv = require("dotenv");

dotenv.config();

function readList(value, fallback = []) {
  if (!value) return fallback;
  return value
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

module.exports = {
  nodeEnv: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 8080),
  databaseUrl:
    process.env.DATABASE_URL ||
    "postgresql://postgres:postgres@localhost:5432/wtf_livepulse",
  jwtSecret: process.env.JWT_SECRET || "wtf_livepulse_dev_secret_change_me",
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "12h",
  corsAllowedOrigins: readList(process.env.CORS_ALLOWED_ORIGINS, ["http://localhost:3000"]),
  jsonBodyLimit: process.env.JSON_BODY_LIMIT || "1mb",
};
