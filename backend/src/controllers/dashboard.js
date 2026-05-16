require("dotenv").config();
const { Lead } = require("../models/leadModel");

const getData = async (req, res) => {
  if (req.method !== "GET") {
    return res
      .status(405)
      .json({ status: false, message: "Method Not Allowed" });
  }
  try {
    const totalLeads = await Lead.findAll();
    const leadsByStatus = await Lead.findAll({
      status: {
        isIn: [["New", "Contacted", "Visit Scheduled", "Closed", "Lost"]],
      },
    });
    const todayLeads = await Lead.findAll({
      created_at: {
        Date: new Date().toISOString().split("T")[0],
      },
    });
    const leadsGroupedBySource = await Lead.findAll({
      source: {
        isIn: [
          ["Website", "Referral", "Social Media", "Email Campaign", "Other"],
        ],
      },
    });

    return res.status(200).json({
      status: true,
      data: {
        totalLeads: totalLeads.length,
        leadsByStatus: leadsByStatus.length,
        todayLeads: todayLeads.length,
        leadsGroupedBySource: leadsGroupedBySource.length,
      },
    });
  } catch (error) {
    console.error("Error fetching user data:", error);
    return res.status(500).json({
      status: false,
      message: error.message,
      error: error.message,
    });
  }
};

module.exports = {
  getData,
};
