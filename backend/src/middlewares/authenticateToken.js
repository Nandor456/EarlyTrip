import jwt from "jsonwebtoken";

function authenticateToken(req, res, next) {
  console.log("Authenticating token for request:", req.method, req.url);
  const authHeader = req.headers["authorization"];
  const token = authHeader && authHeader.split(" ")[1];
  if (!token) {
    console.log("No token provided");
    return res.status(401).json({ message: "No access token provided" });
  }
  const secretKey = process.env.JWT_SECRET;
  jwt.verify(token, secretKey, (err, decoded) => {
    if (err) {
      // Token is invalid or expired
      if (err.name === "TokenExpiredError") {
        console.log("Token expired:", err);
        return res.status(401).json({
          message: "Access token expired",
          code: "TOKEN_EXPIRED",
        });
      } else {
        console.log("Token invalid:", err);
        return res.status(401).json({
          message: "Invalid access token",
          code: "TOKEN_INVALID",
        });
      }
    }

    // 4. Token is valid - attach user info to request
    req.user = decoded;
    console.log("Token valid for user:", decoded);
    next();
  });
}

export default authenticateToken;
