import pool from "../config/database.config.js";

async function requireGroupAdmin(req, res, next) {
  const userId = req.user?.user_id;
  const groupId = req.params?.group_id;

  if (!userId) {
    return res.status(401).json({ message: "Unauthorized" });
  }

  if (!groupId) {
    return res.status(400).json({ message: "group_id is required" });
  }

  try {
    const result = await pool.query(
      `
      SELECT admin_id
      FROM chat_groups
      WHERE group_id = $1
      LIMIT 1
      `,
      [groupId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "Group not found" });
    }

    const adminId = result.rows[0].admin_id;
    if (String(adminId) !== String(userId)) {
      return res.status(403).json({ message: "Forbidden: admin only" });
    }

    return next();
  } catch (error) {
    return res.status(500).json({ message: "Database query error", error });
  }
}

export default requireGroupAdmin;
