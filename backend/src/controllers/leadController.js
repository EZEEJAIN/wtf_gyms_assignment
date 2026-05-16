require("dotenv").config();
const { Lead } = require("../models/leadModel");

const createLeads = async (req, res) => {
  if (req.method !== "POST") {
    return res
      .status(405)
      .json({ status: false, message: "Method Not Allowed" });
  }

  try {
    const { full_name, phone, email, source, status, assigned_to } = req.body;

    if (
      !full_name ||
      !phone ||
      !email ||
      !source ||
      !assigned_to ||
      status === undefined
    ) {
      return res
        .status(400)
        .json({ status: false, message: "Missing required fields" });
    }

    const newLead = {
      full_name,
      phone,
      email,
      source,
      status,
      assigned_to,
    };

    const contentList = JSON.parse(JSON.stringify(newLead));
    const savedData = await Lead.create(contentList);

    return res.status(200).json({
      status: true,
      success: true,
      message: "data uploaded successfully",
      data: savedData,
    });
  } catch (error) {
    console.error("Error uploading:", error);
    return res.status(500).json({ status: false, message: "Server error" });
  }
};

const getLeads = async (req, res) => {
  if (req.method !== "GET") {
    return res
      .status(405)
      .json({ status: false, message: "Method Not Allowed" });
  }
  try {

    const { search } = req.query;
    if (!search) {
      const lead = await Lead.findAll();
      return res.status(200).json({
        status: true,
        message: "data fetched successfully",
        data: lead,
      });
    } else {
      const searchLower = search.toLowerCase();
      const filteredLead = lead.filter((item) => {
        return (
          item.full_name.toLowerCase().includes(searchLower) ||
          item.email.toLowerCase().includes(searchLower) ||
          item.phone.toLowerCase().includes(searchLower) ||
          item.source.toLowerCase().includes(searchLower) ||
          item.status.toString().toLowerCase().includes(searchLower) ||
          item.assigned_to.toLowerCase().includes(searchLower)
        );
      });
      return res.status(200).json({
        status: true,
        message: "data fetched successfully",
        data: filteredLead,
      });
    }

  } catch (error) {
    console.error("Error fetching user data:", error);
    return res.status(500).json({
      status: false,
      message: error.message,
      error: error.message,
    });
  }
};

const updateLeads = async (req, res) => {
  if (req.method !== "PUT") {
    return res
      .status(405)
      .json({ status: false, message: "Method Not Allowed" });
  }

  try {
    const { id, full_name, phone, email, source, status, assigned_to } =
      req.body;

    const isCreate = !id;

    if (isCreate) {
      return res
        .status(400)
        .json({ status: false, message: "Lead ID is required for update" });
    }

    const lead = await Lead.findById(id);

    if (!lead) {
      return res.status(404).json({ status: false, message: "Lead not found" });
    }

    const isStatusExist = await Lead.findOne({ where: { status } });
    if (!isStatusExist) {
      return res
        .status(400)
        .json({ status: false, message: "Invalid status value" });
    }
    const updateLead = await Lead.update({
      full_name,
      phone,
      email,
      source,
      status,
      assigned_to,
    });

    return res.status(200).json({
      status: true,
      message: "Lead updated successfully",
      data: updateLead,
    });
  } catch (error) {
    console.error("Error in upserting category:", error);
    return res.status(500).json({
      status: false,
      message: "Something went wrong while processing category",
      error: error.message,
    });
  }
};

module.exports = {
  getLeads,
  createLeads,
  updateLeads,
};
