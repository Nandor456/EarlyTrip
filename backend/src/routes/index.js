import express from "express";
import authRoutes from "./auth.routes.js";
import authenticateToken from "../middlewares/authenticateToken.js";
import chatRoutes from "./chat.routes.js";
import userRoutes from "./user.routes.js";

const router = express.Router();

router.use("/auth", authRoutes);
router.use(authenticateToken);
router.use("/chat", chatRoutes);
router.use("/users", userRoutes);
//rest of the paths will go here
export default router;
