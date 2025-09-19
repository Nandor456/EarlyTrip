import express from "express";
import upload from "../config/multer.config.js";
import { registerUser, loginUser } from "../controllers/auth.controller.js";
import {
  validateLogin,
  validateRegistration,
} from "../middlewares/auth.middleware.js";
import { refreshAccessToken } from "../controllers/auth.controller.js";
const router = express.Router();

router.post(
  "/register",
  upload.single("profilePic"),
  validateRegistration,
  registerUser
);
router.post("/login", validateLogin, loginUser);
router.post("/refresh", refreshAccessToken);

export default router;
