import express from "express";
import {
	getAllUsers,
	getNotifications,
	getUser,
	searchUsers,
	acceptFriendRequest,
	rejectFriendRequest,
	sendFriendRequest,
} from "../controllers/user.controller.js";
const router = express.Router();

router.get("/", getAllUsers);
router.get("/search", searchUsers);
router.get("/notifications", getNotifications);
router.get("/profile", getUser);
router.post("/:targetUserId/friend-requests", sendFriendRequest);

router.post("/:fromUserId/friend-requests/accept", acceptFriendRequest);
router.post("/:fromUserId/friend-requests/reject", rejectFriendRequest);

export default router;
