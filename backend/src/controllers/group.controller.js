import pool from "../config/database.config.js";
import { saveMessageToDB } from "../services/database.service.js";
export function getGroups(req, res) {
  console.log("Fetching groups for user:", req.user.user_id);
  const query = `
        SELECT g.group_id, g.name, g.group_image, g.admin_id, g.created_at
        FROM chat_groups g
        JOIN group_memberships gm on g.group_id = gm.group_id
        JOIN users u ON gm.user_id = u.user_id
        WHERE u.user_id = $1
    `;
  pool.query(query, [req.user.user_id], (err, result) => {
    if (err) {
      console.error("Error fetching groups:", err);
      return res.status(500).json({ message: "Internal server error" });
    }
    console.log("Groups fetched for user:", req.user.user_id, result.rows);
    console.log({ groups: result.rows });
    res.status(200).json({ groups: result.rows });
  });
}

export function createChatGroup(req, res) {
  console.log("Creating chat group with data:", req.body);

  const { groupName, memberIds } = req.body;

  if (!groupName || !memberIds || !Array.isArray(memberIds)) {
    return res
      .status(400)
      .json({ message: "groupName and memberIds array are required" });
  }
  if (memberIds.length === 0) {
    return res
      .status(400)
      .json({ message: "At least one memberId must be provided" });
  }

  const creatorId = req.user.user_id;
  const queryInsertGroup = `
    INSERT INTO chat_groups (name, admin_id, created_at)
    VALUES ($1, $2, NOW())
    RETURNING group_id
  `;

  pool.query(queryInsertGroup, [groupName, creatorId], (err, result) => {
    if (err) {
      console.error("Error creating group:", err);
      return res.status(500).json({ message: "Internal server error" });
    }

    const newGroupId = result.rows[0].group_id;

    // Include creator in the members list
    const allMemberIds = [...memberIds, creatorId];

    const values = [];
    const params = [];

    allMemberIds.forEach((memberId, index) => {
      const paramIndex1 = index * 2 + 1;
      const paramIndex2 = index * 2 + 2;
      values.push(`($${paramIndex1}, $${paramIndex2})`);
      params.push(newGroupId, memberId);
    });

    const queryInsertMemberships = `
      INSERT INTO group_memberships (group_id, user_id)
      VALUES ${values.join(", ")}
    `;

    pool.query(queryInsertMemberships, params, (err) => {
      if (err) {
        console.error("Error adding members to group:", err);
        return res.status(500).json({ message: "Internal server error" });
      }

      const queryGetGroup = `
        SELECT group_id, name, admin_id, created_at
        FROM chat_groups 
        WHERE group_id = $1
      `;

      pool.query(queryGetGroup, [newGroupId], (err, groupResult) => {
        if (err) {
          console.error("Error fetching created group:", err);
          return res.status(500).json({ message: "Internal server error" });
        }

        const newGroup = groupResult.rows[0];
        console.log("Group created successfully:", newGroup);

        // ✅ notify members in real-time
        const io = req.app.locals.io;
        allMemberIds.forEach((memberId) => {
          io.to(`user_${memberId}`).emit("group_created", newGroup);
        });

        res.status(201).json({
          groups: newGroup,
        });
      });
    });
  });
}

export function getGroupMembers(req, res) {
  const groupId = req.params.group_id;
  const query = `
        SELECT u.user_id, u.first_name, u.last_name, u.email, u.profile_pic_url
        FROM users u
        JOIN group_memberships gm ON u.user_id = gm.user_id
        WHERE gm.group_id = $1
    `;
  pool.query(query, [groupId], (err, result) => {
    if (err) {
      console.error("Error fetching group members:", err);
      return res.status(500).json({ message: "Internal server error" });
    }
    console.log("Members fetched for group:", groupId, result.rows);
    res.status(200).json({ members: result.rows });
  });
}

export function addMembersToGroup(req, res) {
  const groupId = req.params.group_id;
  const { memberIds } = req.body;

  if (!Array.isArray(memberIds) || memberIds.length === 0) {
    return res.status(400).json({ message: "memberIds array is required" });
  }

  const ids = memberIds.map((id) => Number(id)).filter((id) => Number.isFinite(id));
  if (ids.length === 0) {
    return res.status(400).json({ message: "memberIds must contain valid numeric IDs" });
  }

  const query = `
        INSERT INTO group_memberships (group_id, user_id)
        SELECT $1, unnest($2::int[])
        ON CONFLICT (group_id, user_id) DO NOTHING
        `;

  pool.query(query, [groupId, ids], (err) => {
    if (err) {
      console.error("Error adding members to group:", err);
      return res.status(500).json({ message: "Internal server error" });
    }
    console.log("Members added to group:", groupId, ids);
    res.status(200).json({ message: "Members added successfully" });
  });
}
export function removeMembersFromGroup(req, res) {
  const groupId = req.params.group_id;
  const { memberIds } = req.body;

  if (!Array.isArray(memberIds) || memberIds.length === 0) {
    return res.status(400).json({ message: "memberIds array is required" });
  }

  const ids = memberIds.map((id) => Number(id)).filter((id) => Number.isFinite(id));
  if (ids.length === 0) {
    return res.status(400).json({ message: "memberIds must contain valid numeric IDs" });
  }

  // Prevent removing the group admin.
  pool.query(
    `
    SELECT admin_id
    FROM chat_groups
    WHERE group_id = $1
    LIMIT 1
    `,
    [groupId],
    (err, result) => {
      if (err) {
        console.error("Error checking group admin:", err);
        return res.status(500).json({ message: "Internal server error" });
      }
      if (result.rows.length === 0) {
        return res.status(404).json({ message: "Group not found" });
      }

      const adminId = Number(result.rows[0].admin_id);
      const filtered = ids.filter((id) => id !== adminId);
      if (filtered.length === 0) {
        return res.status(400).json({ message: "Cannot remove group admin" });
      }

      const query = `
            DELETE FROM group_memberships
            WHERE group_id = $1
              AND user_id = ANY($2::int[])
            `;

      pool.query(query, [groupId, filtered], (err) => {
        if (err) {
          console.error("Error removing members from group:", err);
          return res.status(500).json({ message: "Internal server error" });
        }
        console.log("Members removed from group:", groupId, filtered);
        res.status(200).json({ message: "Members removed successfully" });
      });
    }
  );
}

export function deleteChatGroup(req, res) {
  const groupId = req.params.group_id;
  const queryDeleteMemberships = `
        DELETE FROM group_memberships
        WHERE group_id = $1
    `;
  const queryDeleteGroup = `
        DELETE FROM chat_groups
        WHERE group_id = $1
    `;
  pool.query(queryDeleteMemberships, [groupId], (err) => {
    if (err) {
      console.error("Error deleting group memberships:", err);
      return res.status(500).json({ message: "Internal server error" });
    }
    pool.query(queryDeleteGroup, [groupId], (err) => {
      if (err) {
        console.error("Error deleting group:", err);
        return res.status(500).json({ message: "Internal server error" });
      }
      console.log("Group deleted with ID:", groupId);
      res.status(200).json({ message: "Group deleted successfully" });
    });
  });
}

export function getGroupMessages(req, res) {
  console.log("Fetching messages for group:", req.params.group_id);

  const groupId = req.params.group_id;
  const query = `
        SELECT message_id, sender_id, content, message_type, timestamp
        FROM messages
        WHERE group_id = $1
        ORDER BY timestamp ASC
    `;
  pool.query(query, [groupId], (err, result) => {
    if (err) {
      console.error("Error fetching group messages:", err);
      return res.status(500).json({ message: "Internal server error" });
    }
    console.log("Messages fetched for group:", groupId, result.rows);
    res.status(200).json({ messages: result.rows });
  });
}

export async function sendGroupMessage(req, res) {
  const groupId = req.params.group_id;
  const { content, type } = req.body;
  const senderId = req.user.user_id;
  if (!content || !type) {
    return res
      .status(400)
      .json({ message: "content and type are required fields" });
  }
  try {
    const savedMessage = await saveMessageToDB(
      groupId,
      senderId,
      content,
      type
    );
    const io = req.app.locals.io;
    io.to(groupId).emit("new_message", savedMessage);
    res.status(201).json({ message: savedMessage });
  } catch (err) {
    console.error("Error sending group message:", err);
    res.status(500).json({ message: "Internal server error" });
  }
}
