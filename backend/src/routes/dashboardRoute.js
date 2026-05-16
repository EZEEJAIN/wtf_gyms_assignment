const express = require("express");
const homeRoute = express.Router();
const JWT = require("../middlewares/auth");
const DASHBOARDSERVICE = require("../controllers/dashboard");

homeRoute.get("/", DASHBOARDSERVICE.getData);

module.exports = homeRoute;
