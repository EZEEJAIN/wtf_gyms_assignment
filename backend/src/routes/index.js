const express = require("express");
const homeRoute=require('./dashboardRoute')
const leadRoute=require('./leadRoute')
const router = express.Router();

router.use("/dashboard", homeRoute);
router.use("/leads", leadRoute); 

module.exports = router;
