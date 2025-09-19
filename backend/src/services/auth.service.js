import pool from "../config/database.config.js";
import bcrypt from "bcrypt";

export async function UserEmailExists(email) {
  const res = await pool.query("SELECT * FROM users WHERE email = $1", [email]);
  if (res.rows.length > 0) {
    return true;
  }
  return false;
}

export async function UserPhoneExists(phone) {
  const res = await pool.query("SELECT * FROM users WHERE phone = $1", [phone]);
  if (res.rows.length > 0) {
    return true;
  }
  return false;
}

export async function userExists(email, password) {
  const res = await pool.query("SELECT password FROM users WHERE email = $1", [
    email,
  ]);

  if (res.rows.length === 0) {
    // No user found
    return {
      success: false,
      message: "User not found",
    };
  }

  const hashedPassword = res.rows[0].password;

  // Compare plaintext password with hashed password
  const match = await bcrypt.compare(password, hashedPassword);

  return {
    success: match,
    message: match ? "Authentication successful" : "Invalid password",
  };
}

export async function getUserByEmail(email) {
  const res = await pool.query("SELECT user_id FROM users WHERE email = $1", [
    email,
  ]);
  if (res.rows.length === 0) {
    return null;
  }
  return res.rows[0].user_id;
}
