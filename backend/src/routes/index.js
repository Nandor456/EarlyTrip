import express from "express";
import authRoutes from "./auth.routes.js";
import authenticateToken from "../middlewares/authenticateToken.js";

const router = express.Router();

router.use("/auth", authRoutes);
router.use(authenticateToken);
//rest of the paths will go here
export default router;
