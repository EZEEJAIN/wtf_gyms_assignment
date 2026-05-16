const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const { jsonBodyLimit, corsAllowedOrigins } = require("./config/env");
const router = require("./routes");
const app = express();
const PORT = process.env.PORT || 5000;

app.use(helmet());
app.use(cors()); 
app.use(express.json({ limit: jsonBodyLimit }));

app.get("/", (_req, res) => {
  res.json({ message: "WTF GYMS is running" });
});

app.use("/api", router);
app.listen(PORT, () => console.log(`WTF Server running on port ${PORT}`));

module.exports = app;
