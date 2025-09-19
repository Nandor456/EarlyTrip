import pool from "../config/database.config.js";

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
