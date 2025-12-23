import express from "express";
import upload from "../config/multer.config.js";
import {
	getAllUsers,
	getFriends,
	getNotifications,
	getUser,
	updateProfilePicture,
	updateUserProfile,
	searchUsers,
	acceptFriendRequest,
	rejectFriendRequest,
	sendFriendRequest,
} from "../controllers/user.controller.js";
const router = express.Router();

router.get("/", getAllUsers);
router.get("/friends", getFriends);
router.get("/search", searchUsers);
router.get("/notifications", getNotifications);
router.get("/profile", getUser);

router.put("/profile", updateUserProfile);
router.post("/profile/picture", upload.single("profilePic"), updateProfilePicture);

router.post("/:targetUserId/friend-requests", sendFriendRequest);

router.post("/:fromUserId/friend-requests/accept", acceptFriendRequest);
router.post("/:fromUserId/friend-requests/reject", rejectFriendRequest);

export default router;
