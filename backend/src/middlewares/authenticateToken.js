import { log } from "console";
import jwt from "jsonwebtoken";

function authenticateToken(req, res, next) {
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) {
    return res.status(401).json({ message: "No access token provided" });
  }
  const secretKey = process.env.JWT_SECRET;
  jwt.verify(token, secretKey, (err, decoded) => {
    if (err) {
      // Token is invalid or expired
      if (err.name === "TokenExpiredError") {
        return res.status(401).json({
          message: "Access token expired",
          code: "TOKEN_EXPIRED",
        });
      } else {
        return res.status(401).json({
          message: "Invalid access token",
          code: "TOKEN_INVALID",
        });
      }
    }

    // 4. Token is valid - attach user info to request
    req.user = decoded;
    log("Token valid for user:", decoded.user_id);
    next();
  });
}

export default authenticateToken;
