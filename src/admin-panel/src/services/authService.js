import { clearSession, getStoredSession, storeSession } from './authSession';
import { proxyRequest } from './apiClient';

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

const ensureAdminUser = (user) => {
  if (user?.role !== 'admin') {
    clearSession();
    throw new Error('Admin privileges required.');
  }

  return mapUser(user);
};

export const hasStoredSession = () => Boolean(getStoredSession());

export const loginAdmin = async ({ username, password }) => {
  const payload = await proxyRequest(
    '/auth/login',
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ username, password }),
    },
    {
      authenticated: false,
      retryOnUnauthorized: false,
    },
  );

  const user = ensureAdminUser(payload?.user);
  storeSession(payload);
  return user;
};

export const loadCurrentAdmin = async () => {
  const payload = await proxyRequest('/me');
  return ensureAdminUser(payload?.user);
};

export const logoutAdmin = async () => {
  try {
    if (hasStoredSession()) {
      await proxyRequest(
        '/auth/logout',
        { method: 'POST' },
        { retryOnUnauthorized: false },
      );
    }
  } finally {
    clearSession();
  }
};

