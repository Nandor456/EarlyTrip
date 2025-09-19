import pool from "../config/database.config.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { getUserByEmail } from "../services/auth.service.js";
export const registerUser = async (req, res) => {
  try {
    console.log("Registering user with data:", req.body);

    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(req.body.password, saltRounds);

    const result = await pool.query(
      "INSERT INTO users (first_name, last_name, email, phone, password, profile_pic_url) VALUES ($1, $2, $3, $4, $5, $6) RETURNING user_id",
      [
        req.body.firstName,
        req.body.lastName,
        req.body.email,
        req.body.phone,
        hashedPassword,
        req.file?.path || null,
      ]
    );

    console.log("User registered with ID:", result.rows[0].user_id);
    return res.status(201).json({
      message: "User registered successfully",
      userId: result.rows[0].user_id,
    });
  } catch (err) {
    console.error("Error inserting user:", err);
    return res.status(500).json({ message: "Internal server error" });
  }
};

export const loginUser = async (req, res) => {
  console.log("Logging in user with data:", req.body);
  const { email } = req.body;
  const user_id = await getUserByEmail(email);
  console.log("user_id fetched:", user_id);

  const payload = {
    user_id,
  };
  const accessToken = jwt.sign(payload, process.env.JWT_SECRET, {
    expiresIn: "30m",
  });
  const refreshToken = jwt.sign(
    {
      user_id,
      type: "refresh",
    },
    process.env.REFRESH_TOKEN_SECRET,
    {
      expiresIn: "7d",
    }
  );
  res.status(200).json({
    accessToken,
    refreshToken,
    message: "Login successful",
    user: { ...payload },
  });
};

export const refreshAccessToken = (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ message: "Refresh token is required" });
  }
  jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET, (err, decoded) => {
    if (err) {
      console.error("Error verifying refresh token:", err);
      return res.status(401).json({ message: "Invalid refresh token" });
    } else {
      if (decoded.type !== "refresh") {
        return res.status(401).json({ message: "Invalid token type" });
      } else {
        const { user_id } = req.body;
        const payload = {
          user_id,
        };
        const newAccessToken = jwt.sign(payload, process.env.JWT_SECRET, {
          expiresIn: "30m",
        });
        console.log("Access token refreshed for user:", decoded.user_id);
        return res
          .status(200)
          .json({ accessToken: newAccessToken, message: "Token refreshed" });
      }
    }
  });
};
