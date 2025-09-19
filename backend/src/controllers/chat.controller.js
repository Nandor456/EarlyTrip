import pool from "../config/database.config.js";

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
    res.status(200).json({ groups: result.rows });
  });
}

export function createChatGroup(req, res) {
  console.log("Creating chat group with data:", req.body);

  const { groupName, memberIds } = req.body;
  console.log("Creating group with name:", groupName, "members:", memberIds);

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

    // Create the VALUES clause dynamically
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

    console.log("Query:", queryInsertMemberships);
    console.log("Params:", params);

    pool.query(queryInsertMemberships, params, (err) => {
      if (err) {
        console.error("Error adding members to group:", err);
        return res.status(500).json({ message: "Internal server error" });
      }

      // Return the complete group data that matches your frontend expectation
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

        console.log("Group created successfully:", groupResult.rows[0]);
        res.status(201).json({
          groups: groupResult.rows[0],
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
  const query = `
        INSERT INTO group_memberships (group_id, user_id)
        VALUES ($1, $2)
        `;
  const membershipValues = memberIds.map((id) => [groupId, id]);
  pool.query(query, membershipValues.flat(), (err) => {
    if (err) {
      console.error("Error adding members to group:", err);
      return res.status(500).json({ message: "Internal server error" });
    }
    console.log("Members added to group:", groupId, memberIds);
    res.status(200).json({ message: "Members added successfully" });
  });
}
export function removeMembersFromGroup(req, res) {
  const groupId = req.params.group_id;
  const { memberIds } = req.body;
  const query = `
        DELETE FROM group_memberships
        WHERE group_id = $1 AND user_id = $2
        `;
  const membershipValues = memberIds.map((id) => [groupId, id]);
  pool.query(query, membershipValues.flat(), (err) => {
    if (err) {
      console.error("Error removing members from group:", err);
      return res.status(500).json({ message: "Internal server error" });
    }
    console.log("Members removed from group:", groupId, memberIds);
    res.status(200).json({ message: "Members removed successfully" });
  });
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
