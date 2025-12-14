import express from "express";
import {
	getAllUsers,
	getNotifications,
	getUser,
	searchUsers,
	sendFriendRequest,
} from "../controllers/user.controller.js";
const router = express.Router();

router.get("/", getAllUsers);
router.get("/search", searchUsers);
router.get("/notifications", getNotifications);
router.get("/profile", getUser);
router.post("/:targetUserId/friend-requests", sendFriendRequest);

export default router;
