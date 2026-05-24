const SESSION_STORAGE_KEY = 'recognita_admin_session';

export const getStoredSession = () => {
  const rawValue = window.sessionStorage.getItem(SESSION_STORAGE_KEY);

  if (!rawValue) {
    return null;
  }

  try {
    return JSON.parse(rawValue);
  } catch {
    window.sessionStorage.removeItem(SESSION_STORAGE_KEY);
    return null;
  }
};

export const storeSession = (session) => {
  window.sessionStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(session));
};

export const clearSession = () => {
  window.sessionStorage.removeItem(SESSION_STORAGE_KEY);
};

export const getAccessToken = () =>
  getStoredSession()?.tokens?.access_token ?? null;

export const getRefreshToken = () =>
  getStoredSession()?.tokens?.refresh_token ?? null;

