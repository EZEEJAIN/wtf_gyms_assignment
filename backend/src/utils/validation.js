const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isUuid(value) {
  return typeof value === "string" && UUID_REGEX.test(value);
}

function parseDateRange(value) {
  if (!value) return { key: "30d", days: 30 };

  if (value === "7d") return { key: "7d", days: 7 };
  if (value === "30d") return { key: "30d", days: 30 };
  if (value === "90d") return { key: "90d", days: 90 };

  return null;
}

module.exports = {
  isUuid,
  parseDateRange,
};
