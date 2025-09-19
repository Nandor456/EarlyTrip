import express from "express";
import {
  getGroups,
  createChatGroup,
  getGroupMembers,
  addMembersToGroup,
  removeMembersFromGroup,
  deleteChatGroup,
} from "../controllers/chat.controller.js";
const router = express.Router();

router.get("/groups", getGroups);
router.post("/groups", createChatGroup);
router.get("/groups/:group_id/members", getGroupMembers);
router.post("/groups/group_id/members", addMembersToGroup);
router.delete("/groups/group_id/members", removeMembersFromGroup);
router.delete("/groups/:group_id", deleteChatGroup);
export default router;
