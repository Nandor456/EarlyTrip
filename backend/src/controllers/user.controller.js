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
    "SELECT user_id, first_name, last_name, email, profile_pic_url, is_dark_theme FROM users WHERE user_id = $1",
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

export async function updateUserProfile(req, res) {
  const userId = req.user.user_id;
  const firstName =
    req.body?.firstName !== undefined ? String(req.body.firstName).trim() : undefined;
  const lastName =
    req.body?.lastName !== undefined ? String(req.body.lastName).trim() : undefined;

  const rawIsDarkTheme = req.body?.isDarkTheme;
  const isDarkTheme =
    rawIsDarkTheme === undefined
      ? undefined
      : typeof rawIsDarkTheme === "boolean"
        ? rawIsDarkTheme
        : String(rawIsDarkTheme).toLowerCase() === "true";

  if (firstName === undefined && lastName === undefined && isDarkTheme === undefined) {
    return res
      .status(400)
      .json({ message: "firstName, lastName and/or isDarkTheme is required" });
  }

  try {
    const result = await pool.query(
      `
      UPDATE users
      SET
        first_name = COALESCE($2, first_name),
        last_name = COALESCE($3, last_name),
        is_dark_theme = COALESCE($4, is_dark_theme)
      WHERE user_id = $1
      RETURNING user_id, first_name, last_name, email, profile_pic_url, is_dark_theme
      `,
      [userId, firstName ?? null, lastName ?? null, isDarkTheme ?? null]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.status(200).json({ user: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Database query error", error });
  }
}

export async function updateProfilePicture(req, res) {
  const userId = req.user.user_id;

  if (!req.file?.path) {
    return res.status(400).json({ message: "profilePic file is required" });
  }

  try {
    const result = await pool.query(
      `
      UPDATE users
      SET profile_pic_url = $2
      WHERE user_id = $1
      RETURNING user_id, first_name, last_name, email, profile_pic_url, is_dark_theme
      `,
      [userId, req.file.path]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.status(200).json({ user: result.rows[0] });
  } catch (error) {
    return res.status(500).json({ message: "Database query error", error });
  }
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
      SELECT
        u.user_id,
        u.first_name,
        u.last_name,
        u.email,
        u.profile_pic_url,
        CASE
          WHEN f_out.status = 'accepted' OR f_in.status = 'accepted' THEN 'accepted'
          WHEN f_out.status = 'pending' OR f_in.status = 'pending' THEN 'pending'
          ELSE 'none'
        END AS friendship_status
      FROM users
      u
      LEFT JOIN friendships f_out
        ON f_out.user_id = $1 AND f_out.friend_id = u.user_id
      LEFT JOIN friendships f_in
        ON f_in.user_id = u.user_id AND f_in.friend_id = $1
      WHERE u.user_id <> $1
        AND (u.first_name ILIKE $2 OR u.last_name ILIKE $2 OR u.email ILIKE $2)
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

export async function getFriends(req, res) {
  const userId = req.user.user_id;

  try {
    const result = await pool.query(
      `
      SELECT
        u.user_id,
        u.first_name,
        u.last_name,
        u.email,
        u.profile_pic_url
      FROM friendships f
      JOIN users u ON u.user_id = f.friend_id
      WHERE f.user_id = $1
        AND f.status = 'accepted'
      ORDER BY u.first_name ASC
      `,
      [userId]
    );

    return res.status(200).json({ friends: result.rows });
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
    const existing = await pool.query(
      `
      SELECT status
      FROM friendships
      WHERE (user_id = $1 AND friend_id = $2)
         OR (user_id = $2 AND friend_id = $1)
      LIMIT 1
      `,
      [fromUserId, targetUserId]
    );

    if (existing.rows.length > 0) {
      const status = existing.rows[0].status;
      if (status === 'accepted') {
        return res.status(200).json({ message: 'Already friends' });
      }
      if (status === 'pending') {
        return res.status(200).json({ message: 'Friend request already pending' });
      }
    }

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

    await pool.query(
      `
      INSERT INTO friendships (user_id, friend_id, status)
      VALUES ($1, $2, 'pending')
      `,
      [fromUserId, targetUserId]
    );

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

export async function acceptFriendRequest(req, res) {
  const toUserId = req.user.user_id;
  const fromUserId = req.params.fromUserId;

  if (!fromUserId) {
    return res.status(400).json({ message: "From user ID is required" });
  }

  try {
    const pending = await pool.query(
      `
      SELECT status
      FROM friendships
      WHERE user_id = $1 AND friend_id = $2
      LIMIT 1
      `,
      [fromUserId, toUserId]
    );

    if (pending.rows.length === 0) {
      // If already accepted, treat as idempotent.
      const accepted = await pool.query(
        `
        SELECT status
        FROM friendships
        WHERE (user_id = $1 AND friend_id = $2)
           OR (user_id = $2 AND friend_id = $1)
        LIMIT 1
        `,
        [fromUserId, toUserId]
      );

      if (accepted.rows.length > 0 && accepted.rows[0].status === 'accepted') {
        return res.status(200).json({ message: 'Already friends' });
      }

      return res.status(404).json({ message: 'No pending friend request found' });
    }

    if (pending.rows[0].status !== 'pending') {
      return res.status(400).json({ message: 'Friend request is not pending' });
    }

    // Mark the original request as accepted.
    await pool.query(
      `
      UPDATE friendships
      SET status = 'accepted'
      WHERE user_id = $1 AND friend_id = $2
      `,
      [fromUserId, toUserId]
    );

    // Ensure reciprocal relationship exists as accepted.
    await pool.query(
      `
      INSERT INTO friendships (user_id, friend_id, status)
      VALUES ($1, $2, 'accepted')
      ON CONFLICT (user_id, friend_id)
      DO UPDATE SET status = 'accepted'
      `,
      [toUserId, fromUserId]
    );

    return res.status(200).json({ message: 'Friend request accepted' });
  } catch (error) {
    return res
      .status(500)
      .json({ message: 'Failed to accept friend request', error });
  }
}

export async function rejectFriendRequest(req, res) {
  const toUserId = req.user.user_id;
  const fromUserId = req.params.fromUserId;

  if (!fromUserId) {
    return res.status(400).json({ message: "From user ID is required" });
  }

  try {
    // Delete only pending relationship rows between these users.
    await pool.query(
      `
      DELETE FROM friendships
      WHERE status = 'pending'
        AND ((user_id = $1 AND friend_id = $2)
          OR (user_id = $2 AND friend_id = $1))
      `,
      [fromUserId, toUserId]
    );

    return res.status(200).json({ message: 'Friend request rejected' });
  } catch (error) {
    return res
      .status(500)
      .json({ message: 'Failed to reject friend request', error });
  }
}

export async function getNotifications(req, res) {
  const userId = req.user.user_id;

  try {
    // Persisted friend requests (pending) as notifications.
    const pendingRequests = await pool.query(
      `
      SELECT
        f.user_id AS from_user_id,
        u.first_name,
        u.last_name,
        u.email,
        u.profile_pic_url,
        f.created_at
      FROM friendships f
      JOIN users u ON u.user_id = f.user_id
      WHERE f.friend_id = $1
        AND f.status = 'pending'
      ORDER BY f.created_at DESC
      `,
      [userId]
    );

    const notifications = pendingRequests.rows.map((r) => ({
      id: `friend_request_${r.from_user_id}_${userId}`,
      type: "FRIEND_REQUEST",
      message: `${r.first_name} ${r.last_name} sent you a friend request`,
      fromUser: {
        user_id: r.from_user_id,
        first_name: r.first_name,
        last_name: r.last_name,
        email: r.email,
        profile_pic_url: r.profile_pic_url,
      },
      created_at: r.created_at,
    }));

    return res.status(200).json({ notifications });
  } catch (error) {
    return res
      .status(500)
      .json({ message: "Failed to load notifications", error });
  }
}
