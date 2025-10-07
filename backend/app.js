import express from "express";
import cors from "cors";
import bodyParser from "body-parser";
import morgan from "morgan";
import helmet from "helmet";
import routes from "./src/routes/index.js";
import path from "path";
import { fileURLToPath } from "url";
import { createServer } from "http";
import { Server } from "socket.io";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// Create HTTP server and integrate with Socket.IO
//----------------------------------------------------------------
const httpServer = createServer(app);
const io = new Server(httpServer, {
  /* options */
});

app.locals.io = io;

io.on("connection", (socket) => {
  console.log("Client connected:", socket.id);

  socket.on("join_group", (groupId) => {
    socket.join(groupId);
    console.log(`Socket ${socket.id} joined group ${groupId}`);

    // notify the client it successfully joined
    socket.emit(`joined_group_${groupId}`, { groupId, status: "ok" });
  });

  socket.on("send_message", ({ groupId, message }) => {
    console.log("Message received for group", groupId, message);
    // broadcast to everyone in the group
    io.to(groupId).emit("new_message", { groupId, message });
  });
});
//----------------------------------------------------------------

const PORT = process.env.PORT || 3000;

app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(morgan("dev"));
app.use(helmet());

app.get("/health", (req, res) => {
  res.json({
    status: "OK",
    timestamp: new Date().toISOString(),
    message: "Server is running",
  });
});

app.use("/api", routes);
httpServer.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT || 3000}`);
});
