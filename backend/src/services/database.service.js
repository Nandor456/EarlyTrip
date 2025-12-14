import pool from "../config/database.config.js";

async function saveMessageToDB(groupId, senderId, content, type) {
  const query = `
    INSERT INTO messages (group_id, sender_id, content, message_type, timestamp)
    VALUES ($1, $2, $3, $4, NOW())
    RETURNING message_id, sender_id, group_id, content, message_type, timestamp
  `;
  try {
    const result = await pool.query(query, [groupId, senderId, content, type]);
    return result.rows[0];
  } catch (err) {
    console.error("Error saving message to DB:", err);
    throw err;
  }
}

export { saveMessageToDB };
