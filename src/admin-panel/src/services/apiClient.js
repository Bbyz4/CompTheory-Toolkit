import {
  clearSession,
  getAccessToken,
  getRefreshToken,
  storeSession,
} from './authSession';

const ADMIN_API_ROOT = '/_admin_api';
const PROXY_API_ROOT = '/proxy';

const parseResponse = async (response) => {
  const text = await response.text();

  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

const errorMessage = (response, payload) =>
  payload?.error?.message ??
  payload?.message ??
  `Request failed with status ${response.status}`;

const buildHeaders = (headers = {}, authenticated = true) => {
  const nextHeaders = {
    Accept: 'application/json',
    ...headers,
  };

  if (authenticated && !nextHeaders.Authorization) {
    const accessToken = getAccessToken();

    if (accessToken) {
      nextHeaders.Authorization = `Bearer ${accessToken}`;
    }
  }

  return nextHeaders;
};

const refreshSession = async () => {
  const refreshToken = getRefreshToken();

  if (!refreshToken) {
    return false;
  }

  const response = await fetch(`${PROXY_API_ROOT}/auth/refresh`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });

  const payload = await parseResponse(response);

  if (!response.ok) {
    clearSession();
    return false;
  }

  storeSession(payload);
  return true;
};

const requestWithRoot = async (
  apiRoot,
  path,
  options = {},
  { authenticated = true, retryOnUnauthorized = true } = {},
) => {
  const response = await fetch(`${apiRoot}${path}`, {
    ...options,
    headers: buildHeaders(options.headers, authenticated),
  });

  const payload = await parseResponse(response);

  if (
    response.status === 401 &&
    authenticated &&
    retryOnUnauthorized &&
    (await refreshSession())
  ) {
    return requestWithRoot(apiRoot, path, options, {
      authenticated,
      retryOnUnauthorized: false,
    });
  }

  if (!response.ok) {
    if (response.status === 401) {
      clearSession();
    }

    throw new Error(errorMessage(response, payload));
  }

  return payload;
};

export const request = (path, options = {}) =>
  requestWithRoot(ADMIN_API_ROOT, path, options);

export const proxyRequest = (
  path,
  options = {},
  requestOptions = {},
) => requestWithRoot(PROXY_API_ROOT, path, options, requestOptions);

