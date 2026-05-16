require("dotenv").config();
const jwt = require("jsonwebtoken");
const { jwtSecret } = require("../config/env");

const JWT_SECRET = jwtSecret;

const verifyToken= (allowedRoles) => (req, res, next) => {
  const token = req.headers.authorization;
  if (!token) {
    return res.status(401).json({ error: "Access denied!!, token is missing" });
  }
  if (!JWT_SECRET) {
    console.error("JWT_SECRET is not defined");
    return res.status(500).json({ error: "Internal server error" });
  }
  const decoded = jwt.verify(token, JWT_SECRET);
  try {
    req.user = decoded;
    if (!allowedRoles.includes(req.user.roleId)) {
      return res.status(403).json({ message: 'Forbidden - permission denied' });
    }
    next();
  } catch (error) {
    console.log("Token verification error:", error.message);

    if (error.name === "TokenExpiredError") {
      console.log("Access token expired, attempting to refresh...");
    } else {
      console.error("Invalid token:", error.message);
      return res.status(401).json({ error: "Invalid token" });
    }
  }
}

module.exports = {
  verifyToken,
};
