import crypto from "crypto";

// In-memory notification store (dev-friendly). Not persisted across restarts.
// Map<userId:string, Array<notification>>
const notificationsByUserId = new Map();

function ensureUserBucket(userId) {
  const key = String(userId);
  if (!notificationsByUserId.has(key)) {
    notificationsByUserId.set(key, []);
  }
  return notificationsByUserId.get(key);
}

export function addFriendRequestNotification({
  toUserId,
  fromUser,
}) {
  const bucket = ensureUserBucket(toUserId);

  const notification = {
    id: crypto.randomUUID(),
    type: "FRIEND_REQUEST",
    message: `${fromUser.first_name} ${fromUser.last_name} sent you a friend request`,
    fromUser: {
      user_id: fromUser.user_id,
      first_name: fromUser.first_name,
      last_name: fromUser.last_name,
      email: fromUser.email,
      profile_pic_url: fromUser.profile_pic_url,
    },
    created_at: new Date().toISOString(),
  };

  bucket.unshift(notification);
  return notification;
}

export function listNotificationsForUser(userId) {
  return ensureUserBucket(userId);
}
