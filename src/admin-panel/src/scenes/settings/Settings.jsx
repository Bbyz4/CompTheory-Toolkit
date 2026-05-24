import { MenuItem, Paper, TextField, Typography } from '@mui/material';
import React from 'react';
import {
  applyTheme,
  getStoredTheme,
  themeOptions,
} from '../../services/themeService';

const selectMenuProps = {
  MenuProps: {
    PaperProps: {
      sx: {
        backgroundColor: 'var(--box)',
        border: '1px solid var(--border)',
        boxShadow: 'none',
      },
    },
  },
};

const Settings = () => {
  const [currentTheme, setCurrentTheme] = React.useState(() => getStoredTheme());

  const handleThemeChange = (event) => {
    const appliedTheme = applyTheme(event.target.value);
    setCurrentTheme(appliedTheme);
  };

  const selectedTheme =
    themeOptions.find((theme) => theme.id === currentTheme) ?? themeOptions[0];

  return (
    <div className="settings">
      <h1>Settings</h1>

      <Paper className="settings-panel" elevation={0}>
        <Typography variant="h5" className="settings-panel-title">
          Appearance
        </Typography>

        <TextField
          select
          label="Theme"
          value={currentTheme}
          onChange={handleThemeChange}
          className="custom-textfield settings-theme-select"
          fullWidth
          SelectProps={{
            ...selectMenuProps,
            renderValue: () => (
              <span className="theme-select-value">
                <span className={`theme-swatch theme-swatch-${selectedTheme.id}`} />
                <span>{selectedTheme.label}</span>
              </span>
            ),
          }}
        >
          {themeOptions.map((theme) => (
            <MenuItem key={theme.id} value={theme.id} className="theme-option-item">
              <span className="theme-select-value">
                <span className={`theme-swatch theme-swatch-${theme.id}`} />
                <span>{theme.label}</span>
              </span>
            </MenuItem>
          ))}
        </TextField>
      </Paper>
    </div>
  );
};

export default Settings;
