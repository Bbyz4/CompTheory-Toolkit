import { request } from './apiClient';

const mapUser = (user) => ({
  id: user.id,
  username: user.username,
  email: user.email,
  role: user.role,
  verified: user.verified,
  isBanned: user.is_banned,
  banReason: user.ban_reason,
  createdAt: user.created_at,
  updatedAt: user.updated_at,
});

export const getUsers = async () => {
  const payload = await request('/users');
  return (payload?.users ?? []).map(mapUser);
};

export const getUser = async (userId) => {
  const users = await getUsers();
  return users.find((user) => user.id === Number(userId)) ?? null;
};

export const banUser = async (userId, reason = 'Banned from admin panel') => {
  const payload = await request(`/users/${userId}/ban`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ reason }),
  });

  return mapUser(payload.user);
};

export const unbanUser = async (userId) => {
  const payload = await request(`/users/${userId}/unban`, {
    method: 'POST',
  });

  return mapUser(payload.user);
};
