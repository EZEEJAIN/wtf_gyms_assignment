const express = require("express");
const leadRoute = express.Router();
const JWT = require("../middlewares/auth");
const LEADSERVICE = require("../controllers/leadController");

leadRoute.get("/", LEADSERVICE.getLeads);
leadRoute.post("/", LEADSERVICE.createLeads);
leadRoute.put("/", LEADSERVICE.updateLeads);

module.exports = leadRoute;
