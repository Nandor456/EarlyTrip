import express from "express";
import {
  getGroups,
  createChatGroup,
  getGroupMembers,
  addMembersToGroup,
  removeMembersFromGroup,
  deleteChatGroup,
  getGroupMessages,
  sendGroupMessage,
} from "../controllers/group.controller.js";
const router = express.Router();

router.get("/", getGroups);
router.post("/", createChatGroup);
router.get("/:group_id/members", getGroupMembers);
router.post("/group_id/members", addMembersToGroup);
router.delete("/group_id/members", removeMembersFromGroup);
router.delete("/:group_id", deleteChatGroup);
router.get("/:group_id/messages", getGroupMessages);
router.post("/:group_id/messages", sendGroupMessage);
export default router;
