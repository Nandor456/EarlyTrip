import pool from "../config/database.config.js";
import {
  addFriendRequestNotification,
  listNotificationsForUser,
} from "../services/notifications.service.js";

export function getAllUsers(req, res) {
  console.log("Fetching all users");

  pool.query(
    "SELECT user_id, first_name, last_name, email, profile_pic_url FROM users",
    (error, results) => {
      if (error) {
        return res.status(500).json({ message: "Database query error", error });
      }
      res.status(200).json({ users: results.rows });
    }
  );
}

export function getUser(req, res) {
  const userId = req.user.user_id;
  console.log("Fetching profile for user ID:", userId);
  pool.query(
    "SELECT user_id, first_name, last_name, email, profile_pic_url FROM users WHERE user_id = $1",
    [userId],
    (error, results) => {
      if (error) {
        return res.status(500).json({ message: "Database query error", error });
      }
      if (results.rows.length === 0) {
        return res.status(404).json({ message: "User not found" });
      }
      console.log("Fetched user profile for user ID:", userId);

      res.status(200).json({ user: results.rows[0] });
    }
  );
}

export async function searchUsers(req, res) {
  const userId = req.user.user_id;
  const query = String(req.query.query ?? "").trim();

  if (!query) {
    return res.status(200).json({ users: [] });
  }

  try {
    const like = `%${query}%`;
    const result = await pool.query(
      `
      SELECT user_id, first_name, last_name, email, profile_pic_url
      FROM users
      WHERE user_id <> $1
        AND (first_name ILIKE $2 OR last_name ILIKE $2 OR email ILIKE $2)
      ORDER BY first_name ASC
      LIMIT 20
      `,
      [userId, like]
    );

    return res.status(200).json({ users: result.rows });
  } catch (error) {
    return res.status(500).json({ message: "Database query error", error });
  }
}

export async function sendFriendRequest(req, res) {
  const fromUserId = req.user.user_id;
  const targetUserId = req.params.targetUserId;

  if (!targetUserId) {
    return res.status(400).json({ message: "Target user ID is required" });
  }
  if (String(targetUserId) === String(fromUserId)) {
    return res.status(400).json({ message: "You cannot add yourself" });
  }

  try {
    const [fromUserResult, targetUserResult] = await Promise.all([
      pool.query(
        "SELECT user_id, first_name, last_name, email, profile_pic_url FROM users WHERE user_id = $1",
        [fromUserId]
      ),
      pool.query("SELECT user_id FROM users WHERE user_id = $1", [targetUserId]),
    ]);

    if (fromUserResult.rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }
    if (targetUserResult.rows.length === 0) {
      return res.status(404).json({ message: "Target user not found" });
    }

    const notification = addFriendRequestNotification({
      toUserId: targetUserId,
      fromUser: fromUserResult.rows[0],
    });

    return res.status(201).json({
      message: "Friend request sent",
      notification,
    });
  } catch (error) {
    return res.status(500).json({ message: "Failed to send friend request", error });
  }
}

export function getNotifications(req, res) {
  const userId = req.user.user_id;
  const notifications = listNotificationsForUser(userId);
  return res.status(200).json({ notifications });
}
