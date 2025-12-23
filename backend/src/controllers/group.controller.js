import pool from "../config/database.config.js";
import { saveMessageToDB } from "../services/database.service.js";
export function getGroups(req, res) {
  console.log("Fetching groups for user:", req.user.user_id);
  const query = `
        WITH my_groups AS (
          SELECT g.group_id, g.name, g.group_image, g.admin_id, g.created_at
          FROM chat_groups g
          JOIN group_memberships gm ON gm.group_id = g.group_id
          WHERE gm.user_id = $1
        ),
        member_counts AS (
          SELECT group_id, COUNT(*)::int AS member_count
          FROM group_memberships
          GROUP BY group_id
        )
        SELECT
          mg.group_id,
          mg.name,
          mg.group_image,
          mg.admin_id,
          mg.created_at,
          mc.member_count,
          CASE
            WHEN mc.member_count = 2 THEN ou.profile_pic_url
            ELSE NULL
          END AS direct_profile_pic_url,
          CASE
            WHEN mc.member_count = 2
              THEN COALESCE(NULLIF(CONCAT_WS(' ', ou.first_name, ou.last_name), ''), ou.email, mg.name)
            ELSE mg.name
          END AS display_name
        FROM my_groups mg
        JOIN member_counts mc ON mc.group_id = mg.group_id
        LEFT JOIN LATERAL (
          SELECT u.first_name, u.last_name, u.email, u.profile_pic_url
          FROM group_memberships gm
          JOIN users u ON u.user_id = gm.user_id
          WHERE gm.group_id = mg.group_id
            AND gm.user_id <> $1
          LIMIT 1
        ) ou ON mc.member_count = 2
        
        -- For direct chats, surface the other user's avatar so the client can show it.
        -- (Group image still takes precedence if present.)
        
        
        ORDER BY mg.created_at DESC NULLS LAST
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

  if (!memberIds || !Array.isArray(memberIds)) {
    return res.status(400).json({ message: "memberIds array is required" });
  }
  if (memberIds.length === 0) {
    return res
      .status(400)
      .json({ message: "At least one memberId must be provided" });
  }

  const creatorId = Number(req.user.user_id);

  // Normalize IDs (frontend may send strings) and drop creator if present.
  const normalizedMemberIds = memberIds
    .map((id) => Number(id))
    .filter((id) => Number.isFinite(id) && id !== creatorId);

  if (normalizedMemberIds.length === 0) {
    return res
      .status(400)
      .json({ message: "memberIds must contain valid numeric IDs" });
  }

  // If it's a direct chat (creator + one other user), auto-name it to the other user's name.
  const isDirectChat = normalizedMemberIds.length === 1;
  if (!isDirectChat) {
    if (typeof groupName !== "string" || groupName.trim().length === 0) {
      return res
        .status(400)
        .json({ message: "groupName is required when creating a group chat" });
    }
  }

  const resolveFinalGroupName = (cb) => {
    if (!isDirectChat) {
      return cb(null, groupName.trim());
    }

    const otherUserId = normalizedMemberIds[0];
    pool.query(
      `
      SELECT first_name, last_name
      FROM users
      WHERE user_id = $1
      LIMIT 1
      `,
      [otherUserId],
      (err, result) => {
        if (err) return cb(err);
        if (result.rows.length === 0) {
          return cb(
            Object.assign(new Error("Other user not found"), {
              statusCode: 404,
            })
          );
        }

        const first = result.rows[0].first_name ?? "";
        const last = result.rows[0].last_name ?? "";
        const fullName = `${first} ${last}`.trim();
        return cb(null, fullName.length === 0 ? "Chat" : fullName);
      }
    );
  };

  resolveFinalGroupName((nameErr, finalGroupName) => {
    if (nameErr) {
      const status = nameErr.statusCode || 500;
      return res.status(status).json({ message: nameErr.message });
    }

    const queryInsertGroup = `
      INSERT INTO chat_groups (name, admin_id, created_at)
      VALUES ($1, $2, NOW())
      RETURNING group_id
    `;

    pool.query(queryInsertGroup, [finalGroupName, creatorId], (err, result) => {
      if (err) {
        console.error("Error creating group:", err);
        return res.status(500).json({ message: "Internal server error" });
      }

      const newGroupId = result.rows[0].group_id;

      // Include creator in the members list (deduped)
      const allMemberIds = Array.from(
        new Set([...normalizedMemberIds, creatorId])
      );

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

  const ids = memberIds
    .map((id) => Number(id))
    .filter((id) => Number.isFinite(id));
  if (ids.length === 0) {
    return res
      .status(400)
      .json({ message: "memberIds must contain valid numeric IDs" });
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

    const io = req.app.locals.io;
    const queryGetGroup = `
      SELECT group_id, name, admin_id, created_at
      FROM chat_groups
      WHERE group_id = $1
    `;

    pool.query(queryGetGroup, [groupId], (groupErr, groupResult) => {
      if (groupErr) {
        console.error("Error fetching group for realtime notify:", groupErr);
        return res.status(200).json({ message: "Members added successfully" });
      }

      const group = groupResult.rows[0];
      if (group) {
        ids.forEach((memberId) => {
          io.to(`user_${memberId}`).emit("group_added", group);
        });
      }

      return res.status(200).json({ message: "Members added successfully" });
    });
  });
}
export function removeMembersFromGroup(req, res) {
  const groupId = req.params.group_id;
  const { memberIds } = req.body;

  if (!Array.isArray(memberIds) || memberIds.length === 0) {
    return res.status(400).json({ message: "memberIds array is required" });
  }

  const ids = memberIds
    .map((id) => Number(id))
    .filter((id) => Number.isFinite(id));
  if (ids.length === 0) {
    return res
      .status(400)
      .json({ message: "memberIds must contain valid numeric IDs" });
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

      const queryGetMemberIds = `
        SELECT user_id
        FROM group_memberships
        WHERE group_id = $1
      `;
      const queryDeleteMemberships = `
        DELETE FROM group_memberships
        WHERE group_id = $1
          AND user_id = ANY($2::int[])
      `;
      const queryDeleteMessages = `
        DELETE FROM messages
        WHERE group_id = $1
      `;
      const queryDeleteGroup = `
        DELETE FROM chat_groups
        WHERE group_id = $1
      `;

      pool.connect((connErr, client, release) => {
        if (connErr) {
          console.error("Error acquiring DB client:", connErr);
          return res.status(500).json({ message: "Internal server error" });
        }

        const rollbackAndRelease = (rollbackErr) => {
          if (rollbackErr) {
            console.error("Error rolling back transaction:", rollbackErr);
          }
          release();
        };

        client.query("BEGIN", (beginErr) => {
          if (beginErr) {
            console.error("Error beginning transaction:", beginErr);
            release();
            return res.status(500).json({ message: "Internal server error" });
          }

          client.query(queryGetMemberIds, [groupId], (membersErr, membersResult) => {
            if (membersErr) {
              console.error("Error fetching group members for removal:", membersErr);
              return client.query("ROLLBACK", (rbErr) => {
                rollbackAndRelease(rbErr);
                return res.status(500).json({ message: "Internal server error" });
              });
            }

            const priorMemberIds = (membersResult?.rows ?? [])
              .map((r) => Number(r.user_id))
              .filter((id) => Number.isFinite(id));

            client.query(queryDeleteMemberships, [groupId, filtered], (delErr) => {
              if (delErr) {
                console.error("Error removing members from group:", delErr);
                return client.query("ROLLBACK", (rbErr) => {
                  rollbackAndRelease(rbErr);
                  return res.status(500).json({ message: "Internal server error" });
                });
              }

              client.query(queryGetMemberIds, [groupId], (afterErr, afterResult) => {
                if (afterErr) {
                  console.error("Error fetching group members after removal:", afterErr);
                  return client.query("ROLLBACK", (rbErr) => {
                    rollbackAndRelease(rbErr);
                    return res.status(500).json({ message: "Internal server error" });
                  });
                }

                const remainingMemberIds = (afterResult?.rows ?? [])
                  .map((r) => Number(r.user_id))
                  .filter((id) => Number.isFinite(id));

                const shouldDeleteGroup =
                  remainingMemberIds.length === 1 && remainingMemberIds[0] === adminId;

                if (!shouldDeleteGroup) {
                  return client.query("COMMIT", (commitErr) => {
                    if (commitErr) {
                      console.error("Error committing transaction:", commitErr);
                      return client.query("ROLLBACK", (rbErr) => {
                        rollbackAndRelease(rbErr);
                        return res.status(500).json({ message: "Internal server error" });
                      });
                    }

                    release();
                    console.log("Members removed from group:", groupId, filtered);
                    return res
                      .status(200)
                      .json({ message: "Members removed successfully", groupDeleted: false });
                  });
                }

                // If only the admin/creator remains, delete the whole group.
                client.query(queryDeleteMessages, [groupId], (msgErr) => {
                  if (msgErr) {
                    console.error("Error deleting group messages:", msgErr);
                    return client.query("ROLLBACK", (rbErr) => {
                      rollbackAndRelease(rbErr);
                      return res.status(500).json({ message: "Internal server error" });
                    });
                  }

                  // Delete remaining membership rows (if FK isn't cascade).
                  client.query(
                    `DELETE FROM group_memberships WHERE group_id = $1`,
                    [groupId],
                    (memErr) => {
                      if (memErr) {
                        console.error("Error deleting remaining memberships:", memErr);
                        return client.query("ROLLBACK", (rbErr) => {
                          rollbackAndRelease(rbErr);
                          return res.status(500).json({ message: "Internal server error" });
                        });
                      }

                      client.query(queryDeleteGroup, [groupId], (groupErr, groupResult) => {
                        if (groupErr) {
                          console.error("Error deleting group:", groupErr);
                          return client.query("ROLLBACK", (rbErr) => {
                            rollbackAndRelease(rbErr);
                            return res.status(500).json({ message: "Internal server error" });
                          });
                        }

                        if ((groupResult?.rowCount ?? 0) === 0) {
                          return client.query("ROLLBACK", (rbErr) => {
                            rollbackAndRelease(rbErr);
                            return res.status(404).json({ message: "Group not found" });
                          });
                        }

                        client.query("COMMIT", (commitErr) => {
                          if (commitErr) {
                            console.error("Error committing transaction:", commitErr);
                            return client.query("ROLLBACK", (rbErr) => {
                              rollbackAndRelease(rbErr);
                              return res.status(500).json({ message: "Internal server error" });
                            });
                          }

                          release();

                          const io = req.app.locals.io;
                          const uniqueRecipients = Array.from(new Set(priorMemberIds));
                          uniqueRecipients.forEach((memberId) => {
                            io.to(`user_${memberId}`).emit("group_deleted", {
                              group_id: Number(groupId),
                            });
                          });

                          console.log("Group deleted (only creator left):", groupId);
                          return res
                            .status(200)
                            .json({ message: "Group deleted successfully", groupDeleted: true });
                        });
                      });
                    }
                  );
                });
              });
            });
          });
        });
      });
    }
  );
}

export function deleteChatGroup(req, res) {
  const groupId = req.params.group_id;
  const queryGetMemberIds = `
    SELECT user_id
    FROM group_memberships
    WHERE group_id = $1
  `;
  const queryDeleteMessages = `
    DELETE FROM messages
    WHERE group_id = $1
  `;
  const queryDeleteMemberships = `
    DELETE FROM group_memberships
    WHERE group_id = $1
  `;
  const queryDeleteGroup = `
    DELETE FROM chat_groups
    WHERE group_id = $1
  `;

  pool.connect((connErr, client, release) => {
    if (connErr) {
      console.error("Error acquiring DB client:", connErr);
      return res.status(500).json({ message: "Internal server error" });
    }

    const rollbackAndRelease = (rollbackErr) => {
      if (rollbackErr) {
        console.error("Error rolling back transaction:", rollbackErr);
      }
      release();
    };

    client.query("BEGIN", (beginErr) => {
      if (beginErr) {
        console.error("Error beginning transaction:", beginErr);
        release();
        return res.status(500).json({ message: "Internal server error" });
      }

      client.query(
        queryGetMemberIds,
        [groupId],
        (membersErr, membersResult) => {
          if (membersErr) {
            console.error(
              "Error fetching group members for delete:",
              membersErr
            );
            return client.query("ROLLBACK", (rbErr) => {
              rollbackAndRelease(rbErr);
              return res.status(500).json({ message: "Internal server error" });
            });
          }

          const memberIds = (membersResult?.rows ?? [])
            .map((r) => Number(r.user_id))
            .filter((id) => Number.isFinite(id));

          client.query(queryDeleteMessages, [groupId], (msgErr) => {
            if (msgErr) {
              console.error("Error deleting group messages:", msgErr);
              return client.query("ROLLBACK", (rbErr) => {
                rollbackAndRelease(rbErr);
                return res
                  .status(500)
                  .json({ message: "Internal server error" });
              });
            }

            client.query(queryDeleteMemberships, [groupId], (memErr) => {
              if (memErr) {
                console.error("Error deleting group memberships:", memErr);
                return client.query("ROLLBACK", (rbErr) => {
                  rollbackAndRelease(rbErr);
                  return res
                    .status(500)
                    .json({ message: "Internal server error" });
                });
              }

              client.query(
                queryDeleteGroup,
                [groupId],
                (groupErr, groupResult) => {
                  if (groupErr) {
                    console.error("Error deleting group:", groupErr);
                    return client.query("ROLLBACK", (rbErr) => {
                      rollbackAndRelease(rbErr);
                      return res
                        .status(500)
                        .json({ message: "Internal server error" });
                    });
                  }

                  if ((groupResult?.rowCount ?? 0) === 0) {
                    return client.query("ROLLBACK", (rbErr) => {
                      rollbackAndRelease(rbErr);
                      return res
                        .status(404)
                        .json({ message: "Group not found" });
                    });
                  }

                  client.query("COMMIT", (commitErr) => {
                    if (commitErr) {
                      console.error("Error committing transaction:", commitErr);
                      return client.query("ROLLBACK", (rbErr) => {
                        rollbackAndRelease(rbErr);
                        return res
                          .status(500)
                          .json({ message: "Internal server error" });
                      });
                    }

                    release();

                    const io = req.app.locals.io;
                    memberIds.forEach((memberId) => {
                      io.to(`user_${memberId}`).emit("group_deleted", {
                        group_id: Number(groupId),
                      });
                    });

                    console.log("Group deleted with ID:", groupId);
                    return res
                      .status(200)
                      .json({ message: "Group deleted successfully" });
                  });
                }
              );
            });
          });
        }
      );
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
