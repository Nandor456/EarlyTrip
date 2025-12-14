import jwt from "jsonwebtoken";

function authenticateSocketToken(socket, next) {
  console.log("Authenticating socket token for socket:", socket.id);
  const authHeader = socket.handshake.headers.authorization;
  const token = authHeader && authHeader.split(" ")[1];

  if (!token) {
    console.error("No token provided");
    return next(new Error("Authentication error"));
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
    if (err) {
      console.error("Invalid token:", err);
      return next(new Error("Authentication error"));
    }

    socket.user = decoded;
    console.log("Socket token valid for user:", decoded);
    next();
  });
}

export default authenticateSocketToken;
