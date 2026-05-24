const THEME_STORAGE_KEY = 'recognita-admin-theme';
const DEFAULT_THEME = 'paper';

export const themeOptions = [
  {
    id: 'paper',
    label: 'Paper',
  },
  {
    id: 'fjord',
    label: 'Fjord',
  },
  {
    id: 'grove',
    label: 'Grove',
  },
];

export const getStoredTheme = () => {
  try {
    return localStorage.getItem(THEME_STORAGE_KEY) || DEFAULT_THEME;
  } catch {
    return DEFAULT_THEME;
  }
};

export const applyTheme = (themeId) => {
  const nextTheme = themeOptions.some((theme) => theme.id === themeId)
    ? themeId
    : DEFAULT_THEME;

  document.documentElement.dataset.theme = nextTheme;

  try {
    localStorage.setItem(THEME_STORAGE_KEY, nextTheme);
  } catch {
    return nextTheme;
  }

  return nextTheme;
};

export const initializeTheme = () => {
  applyTheme(getStoredTheme());
};
