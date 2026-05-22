const API_ROOT = '/_admin_api';

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

export const request = async (path, options = {}) => {
  const response = await fetch(`${API_ROOT}${path}`, {
    headers: {
      Accept: 'application/json',
      ...(options.headers ?? {}),
    },
    ...options,
  });

  const payload = await parseResponse(response);

  if (!response.ok) {
    const message =
      payload?.error?.message ??
      payload?.message ??
      `Request failed with status ${response.status}`;

    throw new Error(message);
  }

  return payload;
};
